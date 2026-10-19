#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@interface FilamentSurface : UIView
@property(nonatomic, readonly) NSString *report;
- (void)loadCompressed:(BOOL)compressed;
- (void)renderFrame;
- (void)shutdown;
@end
NS_ASSUME_NONNULL_END
