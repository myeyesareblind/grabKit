GrabKit
=======================
GrabKit is an iOS Objective-C library offering simple and unified methods to retrieve photo albums on Facebook, Flickr, Picasa, iPhone/iPad and Instagram (and more to come...)


Abstract
--------
In this fork, methods to grab comments of the photo and featured photos feed are added.


Comments Grab
--------
Grabs public users comments of the photo.

#### GRKServiceCommentsGrabberProtocol:
        @protocol GRKServiceCommentsGrabberProtocol <NSObject>
        @required

        -(void) commentsOfPhoto:(GRKPhoto*)photo
        withCommentsAtPageIndex:(NSUInteger)pageIndex
        withNumberOfCommentsPerPage:(NSUInteger)numberOfCommentsPerPage
               andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock
                  andErrorBlock:(GRKErrorBlock)errorBlock;

        @end



CompleteBlock will recieve an array of GRKComments. The comment is described with:

#### GRKComment:
        @property (nonatomic, strong, readonly) NSString*  commentId;
        @property (nonatomic, strong, readwrite) NSDate*    publishDate;
        @property (nonatomic, strong, readwrite) NSString*  message;
        @property (nonatomic, strong, readwrite) GRKAuthor* author;

There is also an helper internal protocol:
#### @protocol GRKCommentsInternalProtocol <NSObject>
        -(BOOL)isResultForCommentsInTheExpectedFormat:(id)result;
        -(GRKComment*)commentWithRawComment:(NSDictionary*)rawComment;

The comments protocol is supported by next grabbers: flickr, insta, facebook.
Picasa is not supported.


Featured Photos grabber
--------
The featured photos are grabbed from:

* Flickr: flickr.interestingness.getList
* Instagram: /media/popular
Facebook does not provide such api.


####GRKServiceFeaturedPhotosGrabberProtocol

        -(void) featuredPhotosAtPageIndex:(NSUInteger)pageOffset
                withNumberOfPhotosPerPage:(NSUInteger)numberOfPhotosPerPage
                         andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock
                            andErrorBlock:(GRKErrorBlock)errorBlock;


Also a new model class is added:
####GRKAuthor
        @interface GRKAuthor
        @property (nonatomic, strong, readwrite) NSString* authorId;
        @property (nonatomic, strong, readwrite) NSString* name;

The featured photos feed is added to the demo application.
