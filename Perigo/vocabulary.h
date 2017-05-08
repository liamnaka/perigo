//
//  vocabulary.h
//  Perigo
//
//  Created by Liam on 1/6/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

#import <UIKit/UIKit.h>

#include <memory>
#include "tensorflow/core/public/session.h"
#include "tensorflow/core/util/memmapped_file_system.h"

@interface vocabulary : NSObject {
    
    @public int start_id;
    @public int end_id;
    @public int unk_id;
}
- (id)init;
- (id)initWithVocab:(NSString*)vocab_file Type:(NSString*)vocab_type;
- (int)word_to_id:(NSString*)word;
- (NSString*)id_to_word:(int)word_id;


@end
