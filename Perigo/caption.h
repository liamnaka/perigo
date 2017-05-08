//
//  caption.h
//  Perigo
//
//  Created by Liam on 1/6/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

#import <UIKit/UIKit.h>

#include <memory>
#include "tensorflow/core/public/session.h"
#include "tensorflow/core/util/memmapped_file_system.h"

@interface caption : NSObject {
    
    @public NSMutableArray<NSNumber *> *sentence;
    tensorflow::Tensor state;

    double logprob;
    @public double score;
}
- (id)init;
- (id)initWithSentence:(NSMutableArray*)sentence withState:(tensorflow::Tensor)state withLogprob:(double)logprob withScore:(double)score;
- (NSComparisonResult)compare:(caption *)otherCaption;


@end
