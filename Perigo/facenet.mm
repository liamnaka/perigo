//
//  coco.mm
//  Perigo
//
//  Created by Liam on 6/25/17.
//  Copyright © 2017 Perigo. All rights reserved.
//


#import <AssertMacros.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import "facenet.h"
#include <sys/time.h>
#include "tensorflow_utils.h"



using namespace std;


//Whether model is memory mapped
const bool model_uses_memory_mapping = true;

// Model File - To reduce app size, only the mapped model is in the bundle
static NSString* model_file_name = model_uses_memory_mapping ? @"facenet_mapped" : @"coco";
static NSString* model_file_type = @"pb";

// Image Input dimensions for model
const int wanted_input_channels = 3;

// Network Nodes
const string input1 = "convert_image/Cast:0";
const string output1 = "embeddings:0";




@implementation facenet


- (void)load_model {
    
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

//Method below written largely by Pete Warden/the tensorflow team, adjusted for RGBA pixel buffer
- (tensorflow::Tensor)image_to_tensor:(CVPixelBufferRef)pixelBuffer {
    
    assert(pixelBuffer != NULL);
    //CVPixelBufferLockFlags unlockFlags = kNilOptions;
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    const int sourceRowBytes = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
    const int image_width = (int)CVPixelBufferGetWidth(pixelBuffer);
    const int image_height = (int)CVPixelBufferGetHeight(pixelBuffer);
    
    unsigned char *sourceBaseAddr = (unsigned char *)(CVPixelBufferGetBaseAddress(pixelBuffer));
    //int image_height;
    unsigned char *sourceStartAddr = sourceBaseAddr;
    
    //Isolating square portion - 100 pixel leeway
    /*if (fullHeight <= (image_width)) {
     image_height = fullHeight;
     sourceStartAddr = sourceBaseAddr;
     } else {
     image_height = image_width;
     const int marginY = ((fullHeight - image_width) / 2);
     sourceStartAddr = (sourceBaseAddr + (marginY * sourceRowBytes));
     }*/
    
    const int image_channels = 4;//For incoming pixel buffer
    
    assert(image_channels >= wanted_input_channels);
    
    tensorflow::Tensor image_tensor(tensorflow::DT_FLOAT,
                                    tensorflow::TensorShape(
                                                            {1,image_height,
                                                                image_width,
                                                                wanted_input_channels}));
    auto image_tensor_mapped = image_tensor.tensor<float,3>();
    tensorflow::uint8 *in = sourceStartAddr;
    assert(image_channels >= wanted_input_channels);
    
    float *out = image_tensor_mapped.data();
    for (int y = 0; y < image_height; ++y) {
        float *out_row = out + (y * image_width * wanted_input_channels);
        for (int x = 0; x < image_width; ++x) {
            const int in_x = y;
            const int in_y = x;
            tensorflow::uint8 *in_pixel =
            in + (in_y * image_width * image_channels) + (in_x * image_channels);
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
    //Unlocking buffer did not fix leak alone, some other memory issue
    //ISSUE WITH PIXEL BUFFER !
    NSLog(@"%@", @"Buffer converted to Tensor");
    
    return image_tensor;
}


//Inference through LSTM and Softmax layers, outputs new_state and softmax tensors
- (std::vector<tensorflow::Tensor>)run_inference:(tensorflow::Tensor)image_tensor {
    
    std::vector<tensorflow::Tensor> output_feed;
    
    tensorflow::Tensor image_feed(tensorflow::DT_FLOAT);
    image_feed = image_tensor;
    
    
    
    if (tf_session.get()) {
        std::vector<tensorflow::Tensor> output;
        tensorflow::Status run_status = tf_session->Run(
                                                        {{input1, image_feed}}, {output1}, {}, &output);
        if (!run_status.ok()) {
            NSLog(@"%@", @"Inference Error");
            LOG(ERROR) << "Running model failed:" << run_status;
        } else {
            output_feed = output;
        }
    }
    
    return output_feed;
}

//Beam Search in Objc++ - Logic from im2txt implementation in Python
//Input: image -> Output: caption
- (NSArray*)coco_search:(UIImage*)image{
    
    CGImageRef imageRef = [image CGImage];
    tensorflow::Tensor image_tensor = [self image_to_tensor:[self pixelBufferFromCGImage:imageRef]];
    
    std::vector<tensorflow::Tensor> model_output = [self run_inference:image_tensor];
    NSLog(@"%@", @"Initial State");
    
    tensorflow::Tensor boxes = model_output[0];
    tensorflow::Tensor scores = model_output[1];
    tensorflow::Tensor classes = model_output[2];
    
    auto boxes_mapped = boxes.tensor<float, 2>();
    auto scores_mapped = scores.tensor<float, 1>();
    auto classes_mapped = classes.tensor<float, 1>();
    
    NSMutableArray *output = [[NSMutableArray alloc] initWithCapacity:3];
    NSMutableArray *out_boxes = [[NSMutableArray alloc] initWithCapacity:100];
    NSMutableArray *out_scores = [[NSMutableArray alloc] initWithCapacity:100];
    NSMutableArray *out_classes = [[NSMutableArray alloc] initWithCapacity:100];
    
    for (int i = 0; i < 100; i++){
        out_boxes[i] =   [[NSArray alloc] initWithObjects: [[NSNumber alloc] initWithFloat:float(boxes_mapped(i,0))],
                          [[NSNumber alloc] initWithFloat:float(boxes_mapped(i,1))],
                          [[NSNumber alloc] initWithFloat:float(boxes_mapped(i,2))],
                          [[NSNumber alloc] initWithFloat:float(boxes_mapped(i,3))],nil];
        out_scores[i] = [[NSNumber alloc] initWithFloat:float(scores_mapped(i))];
        out_classes[i] = [[NSNumber alloc] initWithInt:int(classes_mapped(i))];
    }
    
    
    output[0] = out_boxes;
    output[1] = out_scores;
    output[2] = out_classes;
    
    return output;
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



@end
