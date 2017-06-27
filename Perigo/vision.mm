//
//  vision.mm
//  Perigo
//
//  Created by Liam on 1/6/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

#import "vision.h"
#import "beam.h"
#import "coco.h"

@interface vision()
{
    beam *eye;
    //coco *coco_eye;
}
@end

@implementation vision

-(id)init
{
    eye = [[beam alloc] init];
    //coco_eye = [[coco alloc] init]; - Coco not yet implemented
    return self;
}

-(void)load_model
{
    [eye load_model];
    //[coco_eye load_model]; - Coco not yet implemented
}

-(NSString*)beam_search:(UIImage*)image
{
    return [eye beam_search:image];
}

-(NSArray*)coco_search:(UIImage*)image
{
    //return [coco_eye coco_search:image]; - Coco not yet implemented
    return [[NSArray alloc] init];
}


@end
