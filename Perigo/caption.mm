//
//  caption.mm
//  Perigo
//
//  Created by Liam on 1/6/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

#import "caption.h"

@implementation caption



- (id)init
{
    return [self initWithSentence:[[NSMutableArray alloc] init] withState:tensorflow::Tensor() withLogprob:0.0 withScore:0.0];
}

//Assuming length of vocab file is 11519 for testing, works with any length
//Parses out "B'" and "' *score"
- (id)initWithSentence:(NSMutableArray*)withSentence withState:(tensorflow::Tensor)withState withLogprob:(double)withLogprob withScore:(double)withScore{
    self = [super init];
    sentence = withSentence;
    state = withState;
    logprob = withLogprob;
    score = withScore;
    return self;
}

- (NSComparisonResult)compare:(caption *)otherCaption {
    return [[NSNumber numberWithDouble:self->score]
            compare:[NSNumber numberWithDouble:otherCaption->score]];
};



@end
