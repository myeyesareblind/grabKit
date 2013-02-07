//
//  GRKServiceCommentsGrabberProtocol.h
//  grabKit
//
//  Created by myeyesareblind on 2/7/13.
//
//

#import <Foundation/Foundation.h>
#import "GRKServiceGrabberProtocol.h"

@class GRKPhoto;
@protocol GRKServiceCommentsGrabberProtocol <NSObject>
@required

-(void) commentsOfPhoto:(GRKPhoto*)photo
withCommentsAtPageIndex:(NSUInteger)pageIndex
withNumberOfCommentsPerPage:(NSUInteger)numberOfCommentsPerPage
       andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock
          andErrorBlock:(GRKErrorBlock)errorBlock;

@end
