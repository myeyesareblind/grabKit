//
//  GRKDemoFeaturedPhotosList.m
//  grabKit
//
//  Created by myeyesareblind on 2/7/13.
//
//

#import "GRKDemoFeaturedPhotosList.h"
#import "GrabKit.h"

@interface GRKDemoFeaturedPhotosList ()
@property (nonatomic, assign)  GRKServiceGrabber<GRKServiceFeaturedPhotosGrabberProtocol> *featuredGrabber;
@end

@implementation GRKDemoFeaturedPhotosList
@synthesize featuredGrabber;

-(id) initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
           andGrabber:(GRKServiceGrabber*)grabber {
    
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if ( self != nil ){
        
        NSAssert([grabber conformsToProtocol:@protocol(GRKServiceFeaturedPhotosGrabberProtocol)], @"grabber must conform to feature grab protocol");
        self.featuredGrabber = (GRKServiceGrabber<GRKServiceFeaturedPhotosGrabberProtocol> *)grabber;
        _lastLoadedPageIndex = 0;
        _nextPageIndexToLoad = 0;
        _photosFeedArray     = [NSMutableArray new];
        
        [self setState:GRKDemoPhotosListStateInitial];
    }
    return self;
}


-(NSArray*)photosForCellAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger rowIndex = kNumberOfPhotosPerCell * indexPath.row + indexPath.section * kNumberOfPhotosPerPage;
    NSRange  indexRange = NSMakeRange(rowIndex, kNumberOfPhotosPerCell);
    NSMutableArray* retArray = [NSMutableArray arrayWithCapacity:_photosFeedArray];
    for (NSInteger i = indexRange.location; i < indexRange.location + indexRange.length; i++){
        if (i < [_photosFeedArray count]) {
            [retArray addObject:[_photosFeedArray objectAtIndex:i]];
            continue ;
        }
        break;
    }
    return retArray;
}


-(void)fillAlbumWithMorePhotos {
    NSUInteger pageToLoad = _nextPageIndexToLoad;
    
    [self setState:GRKDemoPhotosListStateGrabbing];
    [self.featuredGrabber featuredPhotosAtPageIndex:pageToLoad
                          withNumberOfPhotosPerPage:kNumberOfPhotosPerPage
                                   andCompleteBlock:^(NSArray* results) {
                                       [_photosFeedArray addObjectsFromArray:results];
                                       _lastLoadedPageIndex = pageToLoad;
                                       if ( [results count] < kNumberOfPhotosPerPage )
                                           [self setState:GRKDemoPhotosListStateAllPhotosGrabbed];
                                       else [self setState:GRKDemoPhotosListStatePhotosGrabbed];

                                   }
                                      andErrorBlock:^(NSError* error){
                                          NSLog(@"error grabbing featured feed: %@", error);
                                      }];
    _nextPageIndexToLoad++;
}


-(void)setState:(GRKDemoPhotosListState)newState {
    if (newState == GRKDemoPhotosListStateInitial) {
    }
    else {
        [super setState:newState];
    }
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSUInteger res = _lastLoadedPageIndex+1;
    if ( state != GRKDemoPhotosListStateAllPhotosGrabbed ) {
        res ++;
    }
    
    return res;
}

- (NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    if ( state > GRKDemoPhotosListStatePhotosGrabbed ){
        
        NSUInteger numberOfPhotos = [[_album photosAtPageIndex:section
                                     withNumberOfPhotosPerPage:kNumberOfPhotosPerPage] count];
        
        return [NSString stringWithFormat:@"Page %d ( %d photos )", section, numberOfPhotos];
    }
    
    return [NSString stringWithFormat:@"Page %d", section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    
    NSUInteger res = 0;
    
    if ( state == GRKDemoPhotosListStateAllPhotosGrabbed && section == _lastLoadedPageIndex ) {
        
        NSUInteger photosCount = [_photosFeedArray count];
        
        // Number of cells with kNumberOfPhotosPerCell photos
        NSUInteger numberOfCompleteCell = photosCount / kNumberOfPhotosPerCell;
        
        // The last cell can contain less than kNumberOfPhotosPerCell photos
        NSUInteger thereIsALastCellWithLessThenFourPhotos = (photosCount % kNumberOfPhotosPerCell)?1:0;
        
        // always add an extra cell
        res =  numberOfCompleteCell + thereIsALastCellWithLessThenFourPhotos  +1 ;
        
        
    } else if ( section > _lastLoadedPageIndex) {
        
        // extra cell
        res = 1;
        
    } else res = kNumberOfRowsPerSection;
    
    
    return res;
    
}

@end
