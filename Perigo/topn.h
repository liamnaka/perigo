//
//  topn.h
//  Perigo
//
//  Created by Liam on 1/6/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

#import <UIKit/UIKit.h>

#include <memory>
#include "tensorflow/core/public/session.h"
#include "tensorflow/core/util/memmapped_file_system.h"
#import "caption.h"
#import "queue.h"

@interface topn : NSObject {
    
    int n;
    //NSMutableArray<caption *> *data;
    PriorityQueue* queue;
}
- (id)init;
- (id)initWithN:(int)size;
- (int)size;
- (void)push:(caption*)caption;
- (NSMutableArray*)extract:(bool)sort;
- (void)reset;


@end
