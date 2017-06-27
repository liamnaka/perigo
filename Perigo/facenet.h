//
//  coco.h
//  Perigo
//
//  Created by Liam on 6/25/17.
//  Copyright © 2017 Perigo. All rights reserved.
//


#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#include <memory>
#include "tensorflow/core/public/session.h"
#include "tensorflow/core/util/memmapped_file_system.h"

@interface facenet : NSObject {
    std::unique_ptr<tensorflow::Session> tf_session;
    std::unique_ptr<tensorflow::MemmappedEnv> tf_memmapped_env;
}

- (void)load_model;
- (NSArray*)coco_search:(UIImage*)image;


@end




