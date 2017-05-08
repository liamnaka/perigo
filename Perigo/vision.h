//
//  vision.h
//  Perigo
//
//  Created by Liam on 1/6/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

#ifndef vision_h
#define vision_h

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

// This is a wrapper class around sight
@interface vision : NSObject

-(void)load_model;
-(NSString*)beam_search:(UIImage*)image;


@end

#endif
