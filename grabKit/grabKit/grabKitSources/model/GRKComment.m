//
//  GRKComment.m
//  grabKit
//
//  Created by myeyesareblind on 1/29/13.
//
//

#import "GRKComment.h"

@implementation GRKComment

@synthesize commentId = _commentId,
publishDate = _publishDate,
message     = _message,
author      = _author;

- (id)initWithCommentID:(NSString *)commentID
                message:(NSString *)message
            publishDate:(NSDate *)publishDate
          commentAuthor:(GRKAuthor *)author {
    
    if ((self = [super init]) != nil){
        _commentId      = commentID;
        _publishDate    = publishDate;
        _author         = author;
        _message        = message;
    }
    return self;
}


- (NSString*)description {
    return [NSString stringWithFormat:@"comment by: %@, on: %@ with ID:%@, message:%@",
            _author,
            _publishDate,
            _commentId,
            _message];
}
@end
