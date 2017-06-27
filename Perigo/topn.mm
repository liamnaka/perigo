//
//  topn.mm
//  Perigo
//
//  Created by Liam on 1/6/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

#import "topn.h"

@implementation topn



- (id)init{
    return [self initWithN:3];
}

//Assuming length of vocab file is 11519 for testing, works with any length
//Parses out "B'" and "' *score"
- (id)initWithN:(int)size{
    self = [super init];
    n = size;
    //data = [NSMutableArray<caption *> new];
    queue = [[PriorityQueue alloc] initWithCapacity:size+1];
    return self;
}

- (int)size{
    //return (int)[data count];
    return (int)[queue size];
}

- (void)push:(caption*)cap{
    [queue add:cap];
    if ([queue size]>n){
        [queue poll];
    }
    
    /*
    
    if ([data count] < n && [data count] > 0){ //If queue is not yet full
        
        if (cap->score < data[0]->score){
            [data insertObject:cap atIndex:0];
            if ([data count]==3){
                [data exchangeObjectAtIndex:1 withObjectAtIndex:2];
            }
        }
        else{
            [data addObject:(cap)];
        }
        
    }
    else if ([data count]==0){ //If queue is empty
        [data addObject:(cap)];
    }
    else { //If queue is full
        int second_smallest = data[1]->score <= data[2]->score ? 1 : 2;
        
        if (cap->score < data[0]->score){
            //[data insertObject:cap atIndex:0];
        }
        else if (cap->score < data[second_smallest]->score){
            //[data addObject:(cap)];
            //[data removeObjectAtIndex:0];
            [data replaceObjectAtIndex:0 withObject:cap];
        }
        else{
            [data exchangeObjectAtIndex:0 withObjectAtIndex:second_smallest];
            [data replaceObjectAtIndex:second_smallest withObject:cap];
        }
        */
 
        /*
        int smallIndex = 0;
        double smallest = data[0]->score;
        
        for (int i = 1; i < [data count]; i++){ //Make sure the [0] is smallest
            double val = data[i]->score;
            if (val < smallest) {
                smallest = val;
                smallIndex = i;
            }
        }
        
        if (smallIndex != 0){
            [data exchangeObjectAtIndex:0 withObjectAtIndex:smallIndex];
        }
        */
        //data = [[data sortedArrayUsingSelector:@selector(compare:)] mutableCopy];
    //}
}

- (NSMutableArray*)extract:(bool)sort{
    /*NSMutableArray* copy = [data copy];
    [data release];
    data = [NSMutableArray new];
    if (sort){
        copy = [[copy sortedArrayUsingSelector:@selector(compare:)] mutableCopy]; //Sort (decsending)
        [copy enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {}];//Reverse direction
    }
    
    return copy;*/
    if (sort){
        
        NSMutableArray *tmp =   [[NSMutableArray alloc] initWithArray: [[queue toArray] sortedArrayUsingComparator:^(caption* a, caption* b) {
            return [[NSNumber numberWithDouble:b->score] compare:[NSNumber numberWithDouble:a->score]];
        }]]; //This is working
        [queue clear];
        return tmp;
        
    }
    else{
        NSMutableArray *tmp =  [[NSMutableArray alloc] initWithArray: [queue toArray]];
        [queue clear];
        return tmp;
    }
}

- (void)reset{
    [queue clear];
    //[data release];
    //data = [NSMutableArray new];
}

@end
