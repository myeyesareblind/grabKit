//
//  GRKComment.h
//  grabKit
//
//  Created by myeyesareblind on 1/29/13.
//
//

#import <Foundation/Foundation.h>

@class GRKAuthor;
@interface GRKComment : NSObject {
    
}

- (id)initWithCommentID:(NSString*)commentID
                message:(NSString*)message
            publishDate:(NSDate*)publishDate
          commentAuthor:(GRKAuthor*)author;

@property (nonatomic, strong, readonly) NSString*  commentId;
@property (nonatomic, strong, readwrite) NSDate*    publishDate;
@property (nonatomic, strong, readwrite) NSString*  message;
@property (nonatomic, strong, readwrite) GRKAuthor* author;

@end
