//
//  beam.mm
//  Perigo
//
//  Created by Liam on 1/6/17.
//  Copyright © 2017 Perigo. All rights reserved.
//


#import <AssertMacros.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import "beam.h"
#import "vocabulary.h"
#import "caption.h"
#import "topn.h"
#include <sys/time.h>
#include "tensorflow_utils.h"
#import "images.h"


using namespace std;


//Whether model is memory mapped
const bool model_uses_memory_mapping = true;

// Model File - To reduce app size, only the mapped model is in the bundle
static NSString* model_file_name = model_uses_memory_mapping ? @"perigo_mapped" : @"perigo";
static NSString* model_file_type = @"pb";

// Label File - Load labels into vocabulary
static NSString* labels_file_name = @"words";
static NSString* labels_file_type = @"txt";

// Image Input dimensions for model
const int wanted_input_width = 299;
const int wanted_input_height = 299;
const int wanted_input_channels = 3;

// Network Nodes
const string input1 = "convert_image/Cast:0";
const string output1 = "lstm/initial_state:0";
const string input2 = "input_feed:0";
const string output2 = "softmax:0";
const string input3 = "lstm/state_feed:0";
const string output3 = "lstm/state:0";

// Caption Gen Settings
const int beam_size = 3;
const int max_caption_length = 20;

// Vocabulary object
vocabulary *vocab;


@implementation beam



- (void)load_model
{
    vocab = [[vocabulary alloc] initWithVocab:labels_file_name Type:labels_file_type];
    tensorflow::Status load_status;
    
    if (model_uses_memory_mapping) {
        load_status = LoadMemoryMappedModel(model_file_name,
                                            model_file_type,
                                            &tf_session,
                                            &tf_memmapped_env);
    }
    else {
        load_status = LoadModel(model_file_name, model_file_type, &tf_session);
    }
    if (!load_status.ok()) {
        LOG(FATAL) << "Couldn't load model: " << load_status;
    }
}



//Processes image_tensor through the Inception portion of the neural net, outputs initital_state
- (std::vector<tensorflow::Tensor>)feed_image:(tensorflow::Tensor)image_tensor
{
    std::vector<tensorflow::Tensor> output;

    if (tf_session.get()) {
        std::vector<tensorflow::Tensor> initial_state;
        tensorflow::Status run_status = tf_session->Run(
                                                        {{input1, image_tensor}}, {output1}, {}, &initial_state);
        if (!run_status.ok()) {
            NSLog(@"%@", @"Initial Inference Error");
            LOG(ERROR) << "Running model failed:" << run_status;
        } else {
            output = initial_state;
        }
    }
    
    return output;
}

//Inference through LSTM and Softmax layers, outputs new_state and softmax tensors
- (std::vector<tensorflow::Tensor>)run_inference:(tensorflow::Tensor)inputs withStates:(tensorflow::Tensor)states
{
    std::vector<tensorflow::Tensor> output_feed;
    std::vector<tensorflow::Tensor> output_states;

    tensorflow::Tensor input_feed(tensorflow::DT_INT64);
    input_feed = inputs;
    tensorflow::Tensor state_feed(tensorflow::DT_FLOAT);
    state_feed = states;
    
    assert(input_feed.IsInitialized() == true);
    assert(state_feed.IsInitialized() == true);

    if (tf_session.get()) {
        std::vector<tensorflow::Tensor> state_output;
        tensorflow::Status run_status = tf_session->Run(
                                                        {{input2, input_feed},{input3, state_feed}}, {output2,output3}, {}, &state_output);
        if (!run_status.ok()) {
            NSLog(@"%@", @"Inference Error");
            LOG(ERROR) << "Running model failed:" << run_status;
        } else {
            output_feed = state_output;
        }
    }
    
    return output_feed;
}

//Beam Search in Objc++ - Logic from im2txt implementation in Python
//Inter and Intra op parallelism in TF Session must be set to 1 to avoid crashes
//Input: image -> Output: caption
- (NSString*)beam_search:(UIImage*)image{
    
    NSDate *startBeam = [NSDate date];//Start inference timer
    
    tensorflow::Tensor image_tensor = [self image_to_tensor:image];
    std::vector<tensorflow::Tensor> initial_state = [self feed_image:image_tensor]; //Retrieve initial state
    NSLog(@"%@", @"Initial State");
    
    NSMutableArray* start_sentence = [[NSMutableArray alloc] init];//Suspect 1
    [start_sentence addObject:[NSNumber numberWithInteger:vocab->start_id]];

    caption *initial_beam = [[caption alloc] initWithSentence:start_sentence withState:initial_state[0] withLogprob:0.0 withScore:0.0];

    //Beam Size = 3
    topn *partial_captions = [[topn alloc] initWithN:(beam_size)];
    [partial_captions push:(initial_beam)];
    topn *complete_captions = [[topn alloc] initWithN:(beam_size)];

    //Max Caption Length = 20
    for (int _ = 0; _ < max_caption_length; _++){
        NSMutableArray<caption *> *partial_captions_list = [partial_captions extract:(false)];
        assert(partial_captions_list.count > 0);

        tensorflow::Tensor input_feed(tensorflow::DT_INT64,
                                      tensorflow::TensorShape({(int)[partial_captions_list count],}));
        tensorflow::Tensor state_feed(tensorflow::DT_FLOAT,
                                      tensorflow::TensorShape({(int)[partial_captions_list count],1024}));

        //Maps of input and state feed to fill tensors
        auto input_map = input_feed.tensor<int64_t, 1>();
        auto state_map = state_feed.tensor<float, 2>();


        for (int i = 0; i < [partial_captions_list count]; i++){ //Assigning values to feed tensors
            //Assigns the ID of the last word to input_feed
            input_map(i) = [[partial_captions_list[i]->sentence lastObject] intValue];

            tensorflow::Tensor temp_state = partial_captions_list[i]->state;//Retrieves state from caption
            auto temp_state_map = temp_state.tensor<float, 2>();
            
            for (int j = 0; j < 1024; j++){
                state_map(i,j) = float(temp_state_map(0,j));
            }
        }

        //Second part of inference
        //NSDate *start = [NSDate date]; //LSTM Timer Start
        
        std::vector<tensorflow::Tensor> inference = [self run_inference:input_feed withStates:state_feed];
        tensorflow::Tensor softmax = inference[0];
        tensorflow::Tensor new_states = inference[1];

        //NSDate *end = [NSDate date]; //LSTM Timer End
        //NSTimeInterval time = [end timeIntervalSinceDate:start];
        //NSLog(@"LSTM Time = %f", time);
        
        auto softmax_mapped = softmax.tensor<float, 2>();
        auto new_states_mapped = new_states.tensor<float, 2>();
        
        //start = [NSDate date];//Sort Timer Start

        for (int i = 0; i < [partial_captions_list count]; i++){//Sorting inference output
            caption *partial_caption = partial_captions_list[i];

            //Extracting state from input_feed
            tensorflow::Tensor state(tensorflow::DT_FLOAT,
                                     tensorflow::TensorShape({1,1024}));
            auto state_mapped = state.tensor<float, 2>();
            for (int j = 0; j < 1024; j++){
                state_mapped(0,j) = new_states_mapped(i,j);
            }

            //Sorting with C++ instead of ObjC went from 0.15/2.4s total sort time to 0.01/0.22s total sort time
            //A whole 2+ seconds quicker making it %40+ faster overall and practical!
            array<float, 2> probs[12000];
            for (int j = 0; j < 12000; j++){
                probs[j] = {float(j),softmax_mapped(i,j)};
            }
            auto comp = []( const array<float, 2>& a, const array<float, 2>& b )
            { return a[1] > b[1]; };
            sort(probs,probs+12000,comp);
            

            for (int j = 0; j < beam_size; j++){
                float top_prob = probs[j][1];
                if (top_prob < 1e-12) continue;

                NSNumber *top_word = [NSNumber numberWithInt:int(probs[j][0])];
                NSMutableArray *sentence = [partial_caption->sentence mutableCopy];
                [sentence addObject: top_word];
                double logprob = partial_caption->logprob + log(top_prob);
                double score = logprob;

                if ([top_word intValue]==vocab->end_id){
                    caption *beam = [[caption alloc] initWithSentence:sentence withState:state withLogprob:logprob withScore:score];
                    [complete_captions push:beam];
                }
                else{
                    caption *beam = [[caption alloc] initWithSentence:sentence withState:state withLogprob:logprob withScore:score];
                    [partial_captions push:beam];
                }
            }
        }//End of sort
        
        //If beam_size = 1, when partial candidates run out
        if ([partial_captions size]==0) break;
        
        //end = [NSDate date]; //Sort Timer End
        //time = [end timeIntervalSinceDate:start];
        //NSLog(@"Sort Time = %f", time);
        
    }//End of beam search
    
    NSLog(@"End of beam search");
    //If complete captions is empty, use partial captions
    if ([complete_captions size]==0){
        complete_captions = partial_captions;
    }
    
    
    //Caption Generation
    NSMutableArray<caption *> *top_sentences = [complete_captions extract:true]; //Retrieving ranked sentences
    NSMutableArray *top_sentence = top_sentences[0]->sentence; //Retrieving highest ranked sentence
    NSMutableString *prefix = [@"" mutableCopy];
    NSMutableString *final_caption = [@"" mutableCopy];
    
    //Express degrees of uncertainty with natural language
    double score = exp(top_sentences[0]->logprob);
    if (score < 0.00001) [prefix appendString:@"very unclear, my guess is "];
    else if (score < 0.0001) [prefix appendString:@"not so clear, this might be "];
    else if (score < 0.001) [prefix appendString:@"this may be "];
    
    for (int i = 1; i < [top_sentence count]; i++){
        NSMutableString *word = [[vocab id_to_word:[top_sentence[i] intValue]] mutableCopy];
        if(![word isEqualToString:@"."]&&![word isEqualToString:@"</S>"]){
            //Ommiting "nintendo" or "wii"
            if ([top_sentence[i] intValue] == 251 || [top_sentence[i] intValue] == 589 ) continue;
            //Inserting spaces after words
            NSString *space = i < [top_sentence count]-2 ? @" " : @"";
            //No spaces before commas
            if (i < [top_sentence count] - 1 ){//Avoid out of bounds
                if ([top_sentence[i+1] intValue] != 16) [word appendString:space];
            }
            else [word appendString:space];
            //Adding that before is for grammatical clarity
            if ([top_sentence[i] intValue] == 10 && [top_sentence[i-1] intValue] != 26)
                [final_caption appendString:@"that "];
            //Appending word to final caption
            [final_caption appendString:[word lowercaseString]];
        }
    }
    
    //Correcting common false guesses
    if ([final_caption containsString:@"a pair of scissors"]){
        [final_caption setString:@"a couple of items on a table"];
    }
    else if ([final_caption containsString:@"a sign that reads"]){
        [final_caption setString:@"a sign with text on it"];
    }
    
    [final_caption insertString:prefix atIndex:0];

    //Clearing captions and tensors from memory
    NSLog(@"%@", @"Clearing memory"); //Most likely unnecessary
    [partial_captions reset];
    [complete_captions reset];
    
    NSDate *endBeam = [NSDate date];
    NSTimeInterval totalTime = [endBeam timeIntervalSinceDate:startBeam];
    NSLog(@"Inference Completed in time of: %f", totalTime);

    return final_caption;
}



//Converts UIImage into Tensor
- (tensorflow::Tensor)image_to_tensor:(UIImage*)target_image {
    
    //First, normalize and crop image
    CGImageRef image = [[[self normalizedImage: target_image] resizedImageByMagick:@"299x299#"] CGImage];
    
    const long width = CGImageGetWidth(image);
    const long height = CGImageGetHeight(image);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *pixelData = (unsigned char *)malloc(height * width * 4); //Allocating memory to buffer
    const int  bytesPerPixel = 4;
    const unsigned long bytesPerRow = bytesPerPixel * width;
    const int bitsPerComponent = 8;
    
    CGContextRef context = CGBitmapContextCreate(pixelData, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGContextRelease(context);
    
    const int image_channels = 4;//For incoming pixel buffer
    assert(image_channels >= wanted_input_channels);
    
    tensorflow::Tensor image_tensor(tensorflow::DT_FLOAT,
                                    tensorflow::TensorShape({height,
                                                            width,
                                                            wanted_input_channels}));
  
    
    auto image_tensor_mapped = image_tensor.tensor<float,3>();
    tensorflow::uint8 *in = pixelData;
    
    float *out = image_tensor_mapped.data();

    for (int y = 0; y < height; ++y) {
        float *out_row = out + (y * width * wanted_input_channels);
        for (int x = 0; x < width; ++x) {
            const int in_x = x; //* image_width) / wanted_input_width;
            const int in_y = y; //* image_height) / wanted_input_height;
            tensorflow::uint8 *in_pixel =
            in + (in_y * bytesPerRow) + ((in_x) * image_channels);
            float *out_pixel = out_row + (x * wanted_input_channels);
            //Expecting RGBA pixel format
            out_pixel[0] = in_pixel[0];
            out_pixel[1] = in_pixel[1];
            out_pixel[2] = in_pixel[2];
        }
    }
        
  
    //Releasing malloc
    free(pixelData);
    NSLog(@"%@", @"Buffer converted to Tensor");
    
    return image_tensor;
}



//Method below written largely by Pete Warden/the tensorflow team, adjusted for RGBA pixel buffer
//Only works for vertically oriented buffers (doesn't account for UIImage orientation)
- (tensorflow::Tensor)buffer_to_tensor:(CVPixelBufferRef)pixelBuffer {
    
    assert(pixelBuffer != NULL);
    //CVPixelBufferLockFlags unlockFlags = kNilOptions;
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    const int sourceRowBytes = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
    const int image_width = (int)CVPixelBufferGetWidth(pixelBuffer);
    const int fullHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
    
    //assert(image_width % 299 == 0 && fullHeight % 299 == 0);
    
    unsigned char *sourceBaseAddr = (unsigned char *)(CVPixelBufferGetBaseAddress(pixelBuffer));
    int image_height;
    unsigned char *sourceStartAddr;
    
    image_height = fullHeight;
    sourceStartAddr = sourceBaseAddr;
    
    int marginX = 0;
    
    //Isolating square portion condense from left?
    if (fullHeight <= (image_width)) {
        image_height = fullHeight;
        marginX = (image_width-image_height)/2;
        sourceStartAddr = sourceBaseAddr;
    } else {
        image_height = image_width;
        int marginY = ((fullHeight - image_width) / 2);
        if (marginY < 10) marginY = 0;
        sourceStartAddr = (sourceBaseAddr + (marginY * sourceRowBytes));
    }
    
    const int image_channels = 4;//Of incoming pixel buffer
    
    assert(image_channels >= wanted_input_channels);
    
    tensorflow::Tensor image_tensor(tensorflow::DT_FLOAT,
                                    tensorflow::TensorShape(
                                                            {wanted_input_height,
                                                                wanted_input_width,
                                                                wanted_input_channels}));
    
    auto image_tensor_mapped = image_tensor.tensor<float,3>();
    tensorflow::uint8 *in = sourceStartAddr;
    
    float *out = image_tensor_mapped.data();
    
    for (int y = 0; y < wanted_input_height; ++y) {
        float *out_row = out + (y * wanted_input_width * wanted_input_channels);
        for (int x = 0; x < wanted_input_width; ++x) {
            const int in_x = (y * image_width) / wanted_input_width;
            const int in_y = (x * image_height) / wanted_input_height;
            tensorflow::uint8 *in_pixel =
            in + (in_y * sourceRowBytes/*image_width * image_channels*/) + ((in_x + marginX) * image_channels);
            float *out_pixel = out_row + (x * wanted_input_channels);
            //Expecting RGBA pixel format
            out_pixel[0] = in_pixel[0];
            out_pixel[1] = in_pixel[1];
            out_pixel[2] = in_pixel[2];
        }
    }
    //std::cout << image_tensor.DebugString() << "\n";
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CVPixelBufferRelease(pixelBuffer);
    
    NSLog(@"%@", @"Buffer converted to Tensor");
    
    return image_tensor;
}



//The helper method below was written by Andrea Finollo
- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image
{
    CGSize frameSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
    NSDictionary *options = @{
                              (__bridge NSString *)kCVPixelBufferCGImageCompatibilityKey: @(NO),
                              (__bridge NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @(NO)
                              };
    CVPixelBufferRef pixelBuffer;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, frameSize.width,
                                          frameSize.height,  kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
                                          &pixelBuffer);
    if (status != kCVReturnSuccess) {
        return NULL;
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *data = CVPixelBufferGetBaseAddress(pixelBuffer);
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data, frameSize.width, frameSize.height,
                                                 8, CVPixelBufferGetBytesPerRow(pixelBuffer), rgbColorSpace,
                                                 (CGBitmapInfo) kCGImageAlphaNoneSkipLast);
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    NSLog(@"%@", @"Image converted to Buffer");
    
    return pixelBuffer;
}



- (UIImage *)normalizedImage:(UIImage*)image {
    if ([image imageOrientation] == UIImageOrientationUp) return image;
    
    UIGraphicsBeginImageContextWithOptions([image size], NO, 1.0);
    [image drawInRect:(CGRect){0, 0, [image size]}];
    UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return normalizedImage;
}




@end
