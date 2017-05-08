//
//  vision.mm
//  Perigo
//
//  Created by Liam on 1/6/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

#import "vision.h"
#import "beam.h"

@interface vision()
{
    beam *eye;
}
@end

@implementation vision

-(id)init
{
    eye = [[beam alloc] init];
    return self;
}

-(void)load_model
{
    [eye load_model];
}

-(NSString*)beam_search:(UIImage*)image
{
    return [eye beam_search:image];
}


@end
