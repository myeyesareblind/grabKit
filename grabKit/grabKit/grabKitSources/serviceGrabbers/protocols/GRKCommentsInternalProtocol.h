//
//  GRKCommentsInternalProtocol.h
//  grabKit
//
//  Created by myeyesareblind on 1/30/13.
//
//

#import <Foundation/Foundation.h>

@class GRKComment;

@protocol GRKCommentsInternalProtocol <NSObject>

@required

-(BOOL)isResultForCommentsInTheExpectedFormat:(id)result;
-(GRKComment*)commentWithRawComment:(NSDictionary*)rawComment;

@end
