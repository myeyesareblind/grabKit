In this fork, methods to grab comments of the photo and featured photos feed are added.
The comments grab protocol:
@protocol GRKServiceCommentsGrabberProtocol <NSObject>

-(void) commentsOfPhoto:(GRKPhoto*)photo
withCommentsAtPageIndex:(NSUInteger)pageIndex
withNumberOfCommentsPerPage:(NSUInteger)numberOfCommentsPerPage
       andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock
          andErrorBlock:(GRKErrorBlock)errorBlock;

CompleteBlock will recieve an array of GRKComments. The comment is described with:
@property (nonatomic, strong, readonly) NSString*  commentId;
@property (nonatomic, strong, readwrite) NSDate*    publishDate;
@property (nonatomic, strong, readwrite) NSString*  message;
@property (nonatomic, strong, readwrite) GRKAuthor* author;

There is also an helper internal protocol:
@protocol GRKCommentsInternalProtocol <NSObject>
-(BOOL)isResultForCommentsInTheExpectedFormat:(id)result;
-(GRKComment*)commentWithRawComment:(NSDictionary*)rawComment;

The comments protocol is supported by next grabbers: flickr, insta, facebook.
Picasa is not supported.


The featured photos feed protocol:

@protocol GRKServiceFeaturedPhotosGrabberProtocol <NSObject>

-(void) featuredPhotosAtPageIndex:(NSUInteger)pageOffset
        withNumberOfPhotosPerPage:(NSUInteger)numberOfPhotosPerPage
                 andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock
                    andErrorBlock:(GRKErrorBlock)errorBlock;

Is supported by: flickr and instagram.
Facebook does not provide such api.

Also a new model class is added:
@interface GRKAuthor
@property (nonatomic, strong, readwrite) NSString* authorId;
@property (nonatomic, strong, readwrite) NSString* name;
