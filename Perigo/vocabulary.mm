//
//  vocabulary.h
//  Perigo
//
//  Created by Liam on 1/6/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

#import "vocabulary.h"
#include <fstream>

@implementation vocabulary



NSString *start_word = @"<S>";
NSString *end_word = @"</S>";
NSString *unk_word =@"<UNK>";
NSMutableArray<NSString *> *reverse_vocab = [NSMutableArray new];
NSMutableDictionary *_vocab = [NSMutableDictionary dictionary];

- (id)init
{
    return [self initWithVocab:@"words" Type:@"txt"];
}

//Assuming length of vocab file is 11519 for testing, works with any length
//Parses out "B'" and "' *score"
- (id)initWithVocab:(NSString*)vocab_file Type:(NSString*)vocab_type{
    self = [super init];
    NSString* labels_path = [[NSBundle mainBundle] pathForResource:vocab_file ofType:vocab_type];
    std::ifstream t;
    t.open([labels_path UTF8String]);
    std::string line;
    std::string delimiter = "' ";
    while (t) {
        std::getline(t, line);
        auto pos = line.find(delimiter);
        line = line.substr(2,pos-2);
        [reverse_vocab addObject:[NSString stringWithCString:line.c_str() encoding: [NSString defaultCStringEncoding]]];
    }
    t.close();
    
    for (int i = 0; i < reverse_vocab.count; i++)
    {
        NSNumber *tempnum = [[NSNumber alloc] initWithInt:i];
        [_vocab setObject:tempnum forKey:reverse_vocab[i]];
    }

    //Testing
    NSLog(@"%@", reverse_vocab[0]);
    NSLog(@"%@", reverse_vocab[2]);
    NSLog(@"%@", reverse_vocab[11518]);
    NSLog(@"%@", _vocab[reverse_vocab[0]]);
    NSLog(@"%@", _vocab[reverse_vocab[2]]);
    NSLog(@"%@", _vocab[@"trudging"]);
    
    //Start and end IDs specific to the pre-trained model
    start_id = 2;
    end_id = 1;
    unk_id = 11518;
    return self;
};
- (int)word_to_id:(NSString*)word{
    return [_vocab[word] intValue];
};
- (NSString*)id_to_word:(int)word_id{
    //if (word_id < [reverse_vocab count]){
        return reverse_vocab[word_id];
   // }
    //else return @"<UNK>";
};

@end
