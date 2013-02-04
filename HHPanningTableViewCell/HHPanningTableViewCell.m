/*
 * Copyright (c) 2012, Pierre Bernard & Houdah Software s.à r.l.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#import "HHPanningTableViewCell.h"

#import "HHDirectionPanGestureRecognizer.h"
#import "HHInnerShadowView.h"

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>


#define HH_PANNING_ANIMATION_DURATION		0.1f
#define HH_PANNING_BOUNCE_DISTANCE			10.0f
#define HH_PANNING_MINIMUM_PAN				20.0f
#define HH_PANNING_MAXIMUM_PAN              0.0f //Set to 0.0f for full view width
#define HH_PANNING_TRIGGER_OFFSET			100.0f
#define HH_PANNING_USE_VELOCITY             YES


@interface HHPanningTableViewCell () <UIGestureRecognizerDelegate>

@property (nonatomic, assign, getter = isDrawerRevealed) BOOL drawerRevealed;
@property (nonatomic, assign, getter = isAnimationInProgress) BOOL animationInProgress;

@property (nonatomic, strong) UIView* containerView;
@property (nonatomic, strong) UIView* shadowView;
@property (nonatomic, strong) UIPanGestureRecognizer* panGestureRecognizer;
@property (nonatomic, assign) CGFloat panOriginX;
@property (nonatomic, assign, getter = isPanning) BOOL panning;

- (void)panningTableViewCellInit;

- (UIView*)createContainerView;
- (UIView*)createShadowView;
- (UIPanGestureRecognizer*)createPanGesureRecognizer;

- (void)setDrawerRevealed:(BOOL)revealed direction:(HHPanningTableViewCellDirection)direction animated:(BOOL)animated;

- (void)updateShadowFrame;

@end

static NSString * const kContainerFrameContext = @"containerFrame";

static HHPanningTableViewCellDirection HHOppositeDirection(HHPanningTableViewCellDirection direction);


@implementation HHPanningTableViewCell

#pragma mark -
#pragma mark Initialization

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString*)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	
	if (self != nil) {
		[self panningTableViewCellInit];
	}
	
    return self;
}

- (id)initWithCoder:(NSCoder*)coder
{
	self = [super initWithCoder:coder];
	
	if (self != nil) {
		[self panningTableViewCellInit];
	}
	
    return self;
}

- (void)panningTableViewCellInit
{
	self.containerView = [self createContainerView];
	self.shadowView = [self createShadowView];
	self.panGestureRecognizer = [self createPanGesureRecognizer];
	
	[self addGestureRecognizer:self.panGestureRecognizer];
	
    _drawerRevealed = NO;
	self.directionMask = 0;
	self.shouldBounce = YES;
    self.panOffset = 60.f;
	
	[self addObserver:self forKeyPath:@"containerView.frame" options:0 context:(__bridge void *)kContainerFrameContext];
}

- (void)awakeFromNib
{
	if ([super respondsToSelector:@selector(awakeFromNib)]) {
		[super awakeFromNib];
	}
}

- (void)prepareForReuse
{
	[super prepareForReuse];
	[self setDrawerRevealed:NO animated:NO];
}

- (UIView*)createContainerView
{
	UIView* containerView = [[UIView alloc] initWithFrame:self.bounds];
	
	[containerView setOpaque:YES];
	[containerView setAutoresizesSubviews:YES];
	[containerView setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
	
	[containerView setBackgroundColor:[UIColor clearColor]];
	
	return containerView;
}

- (UIView*)createShadowView
{
	UIView* shadowView = [[HHInnerShadowView alloc] initWithFrame:self.bounds];
	
	[shadowView setOpaque:NO];
	[shadowView setUserInteractionEnabled:NO];
	[shadowView setAutoresizesSubviews:YES];
	[shadowView setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
    
	return shadowView;
}

- (UIPanGestureRecognizer*)createPanGesureRecognizer
{
	HHDirectionPanGestureRecognizer* gestureRecognizer = [[HHDirectionPanGestureRecognizer alloc] initWithTarget:self
																										  action:@selector(gestureRecognizerDidPan:)];
	
	gestureRecognizer.direction = HHDirectionPanGestureRecognizerHorizontal;
	gestureRecognizer.delegate = self;
	
	return gestureRecognizer;
}


#pragma mark -
#pragma mark Finalization

- (void)dealloc
{
	[self removeObserver:self forKeyPath:@"containerView.frame" context:(__bridge void *)kContainerFrameContext];
}


#pragma mark -
#pragma mark Accessors

@synthesize drawerView = _drawerView;

@synthesize directionMask = _directionMask;
@synthesize shouldBounce = _shouldBounce;

@synthesize drawerRevealed = _drawerRevealed;
@synthesize animationInProgress = _animationInProgress;

@synthesize containerView = _containerView;
@synthesize shadowView = _shadowView;
@synthesize panGestureRecognizer = _panGestureRecognizer;

@synthesize panOriginX = _panOriginX;
@synthesize panning = _panning;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == (__bridge void *)kContainerFrameContext) {
		[self updateShadowFrame];
	}
	else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


#pragma mark -
#pragma mark API

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
	[super setSelected:selected animated:animated];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
	if (highlighted && [self isDrawerRevealed]) {
		return;
	}
	
	[super setHighlighted:highlighted animated:animated];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated;
{
	if (editing && [self isDrawerRevealed]) {
		[self setDrawerRevealed:NO animated:NO];
	}
	
	[super setEditing:editing animated:animated];
}

- (void)setDrawerRevealed:(BOOL)revealed animated:(BOOL)animated
{
	NSInteger directionMask = self.directionMask;
	
	if (HHPanningTableViewCellDirectionRight & directionMask) {
		[self setDrawerRevealed:revealed direction:HHPanningTableViewCellDirectionRight animated:animated];
	}
	else if (HHPanningTableViewCellDirectionLeft & directionMask) {
		[self setDrawerRevealed:revealed direction:HHPanningTableViewCellDirectionLeft animated:animated];
	}
}

- (void)setDrawerRevealed:(BOOL)revealed direction:(HHPanningTableViewCellDirection)direction animated:(BOOL)animated {
    if (self.drawerRevealed != revealed) {
        if ([self isEditing] || (self.drawerView == nil)) {
            return;
        }
        
        self.drawerRevealed = revealed;
        
        UIView *drawerView = self.drawerView;
        UIView *shadowView = self.shadowView;
        UIView *containerView = self.containerView;
        CGRect frame = [containerView frame];
        
        UIView *cellView = self;
        CGRect bounds = [cellView bounds];
        CGFloat duration = animated ? HH_PANNING_ANIMATION_DURATION : 0.0f;
        
        [cellView addSubview:drawerView];
        [cellView addSubview:shadowView];
        [cellView addSubview:containerView];
        
        if (revealed) {
            
            
            if (direction == HHPanningTableViewCellDirectionRight) {
                frame.origin.x = bounds.origin.x + bounds.size.width - self.panOffset;
            }
            else {
                frame.origin.x = bounds.origin.x - bounds.size.width + self.panOffset;
            }
            
            self.animationInProgress = YES;
            BOOL shouldBounce = self.shouldBounce;
            
            if (!shouldBounce) {
            [UIView animateWithDuration:duration
                                  delay:0.0f
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                                 [containerView setFrame:frame];
                             } completion:^(BOOL finished) {
                                 self.animationInProgress = NO;
                             }];
            } else {
                CGFloat bounceDuration = duration;
                CGFloat offsetX = containerView.frame.origin.x+containerView.frame.size.width;
                CGFloat bounceMultiplier = fminf(fabsf(offsetX / HH_PANNING_TRIGGER_OFFSET), 1.0f);
                CGFloat bounceDistance = bounceMultiplier * HH_PANNING_BOUNCE_DISTANCE;
                
                if (offsetX < 0.0f) {
                    bounceDistance *= -1.0;
                }
                
                self.animationInProgress = YES;
                
            [UIView animateWithDuration:duration
                                  delay:0.0f
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                                 [containerView setFrame:frame];
                             } completion:^(BOOL finished) {
                                 [UIView animateWithDuration:bounceDuration
                                                       delay:0.0f
                                                     options:UIViewAnimationCurveLinear
                                                  animations:^{
                                                      [containerView setFrame:CGRectOffset(frame, -bounceDistance, 0.0f)];
                                                  } completion:^(BOOL finished) {
                                                      [UIView animateWithDuration:bounceDuration
                                                                            delay:0.0f
                                                                          options:UIViewAnimationCurveLinear
                                                                       animations:^{
                                                                           [containerView setFrame:frame];
                                                                       } completion:^(BOOL finished) {
                                                                           self.animationInProgress = NO;
                                                                       }];
                                                  }];
                             }];
            }
        } else {
            frame.origin.x = 0.0;
            
            BOOL shouldBounce = self.shouldBounce;
            
            if (shouldBounce) {
                CGFloat bounceDuration = duration;
                CGFloat offsetX = containerView.frame.origin.x;
                CGFloat bounceMultiplier = fminf(fabsf(offsetX / HH_PANNING_TRIGGER_OFFSET), 1.0f);
                CGFloat bounceDistance = bounceMultiplier * HH_PANNING_BOUNCE_DISTANCE;
                
                if (offsetX < 0.0f) {
                    bounceDistance *= -1.0;
                }
                
                self.animationInProgress = YES;
                
                [UIView animateWithDuration:duration
                                      delay:0.0f
                                    options:UIViewAnimationOptionCurveEaseOut
                                 animations:^{
                                     [containerView setFrame:frame];
                                 } completion:^(BOOL finished) {
                                     [UIView animateWithDuration:bounceDuration
                                                           delay:0.0f
                                                         options:UIViewAnimationCurveLinear
                                                      animations:^{
                                                          [containerView setFrame:CGRectOffset(frame, bounceDistance, 0.0f)];
                                                      } completion:^(BOOL finished) {
                                                          [UIView animateWithDuration:bounceDuration
                                                                                delay:0.0f
                                                                              options:UIViewAnimationCurveLinear
                                                                           animations:^{
                                                                               [containerView setFrame:frame];
                                                                           } completion:^(BOOL finished) {
                                                                               [drawerView removeFromSuperview];
                                                                               [shadowView removeFromSuperview];
                                                                               
                                                                               self.animationInProgress = NO;
                                                                           }];
                                                      }];
                                 }];
            } else {
                self.animationInProgress = YES;
                
                [UIView animateWithDuration:duration
                                      delay:0.0f
                                    options:UIViewAnimationOptionCurveEaseOut
                                 animations:^{
                                     [containerView setFrame:frame];
                                 } completion:^(BOOL finished) {
                                     [drawerView removeFromSuperview];
                                     [shadowView removeFromSuperview];
                                     
                                     self.animationInProgress = NO;
                                 }];
            }
        }
    }
}


#pragma mark -
#pragma mark Gesture recognizer

- (BOOL)gestureRecognizer:(UIGestureRecognizer*)gestureRecognizer shouldReceiveTouch:(UITouch*)touch
{
	BOOL shouldReceiveTouch = (! self.animationInProgress) && (! self.editing) && (self.drawerView != nil);
    
    if (shouldReceiveTouch) {
        UITableView* tableView = (id)[self superview];
        
        if ([tableView isKindOfClass:[UITableView class]]) {
            shouldReceiveTouch = ! (tableView.isDragging || tableView.isDecelerating);
        }
    }
    
    if (shouldReceiveTouch) {
        id<HHPanningTableViewCellDelegate> delegate = self.delegate;
        
        if ([delegate respondsToSelector:@selector(panningTableViewCell:shouldReceivePanningTouch:)]) {
            shouldReceiveTouch  = [delegate panningTableViewCell:self shouldReceivePanningTouch:touch];
        }
    }
    
    return shouldReceiveTouch;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer*)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer*)otherGestureRecognizer
{
	if ([gestureRecognizer isKindOfClass:[HHDirectionPanGestureRecognizer class]]) {
		HHDirectionPanGestureRecognizer *panGestureRecognizer = (HHDirectionPanGestureRecognizer*)gestureRecognizer;
		
		return (!panGestureRecognizer.panRecognized);
	}
	
    return YES;
}

- (void)gestureRecognizerDidPan:(UIPanGestureRecognizer*)gestureRecognizer {
    if (!self.animationInProgress) {
        
        UIGestureRecognizerState state = gestureRecognizer.state;
        
        if (state == UIGestureRecognizerStateBegan) {
            UIView *drawerView = self.drawerView;
            UIView *shadowView = self.shadowView;
            UIView *containerView = self.containerView;
            
            [self addSubview:drawerView];
            [self addSubview:shadowView];
            [self addSubview:containerView];
            
            [self setSelected:NO];
            
            self.panOriginX = self.containerView.frame.origin.x;
            self.panning = NO;
        }
        else if (state == UIGestureRecognizerStateChanged) {
            CGPoint translation = [gestureRecognizer translationInView:self];
            CGFloat totalPanX = translation.x;
            
            if (!self.panning) {
                if (fabsf(totalPanX) <= HH_PANNING_MINIMUM_PAN) {
                    totalPanX = 0.0f;
                }
                else {
                    self.panning = YES;
                }
            }
            
            UIView *containerView = self.containerView;
            CGRect containerViewFrame = [containerView frame];
            
            containerViewFrame.origin.x = self.panOriginX + totalPanX;
            
            CGFloat width = (HH_PANNING_MAXIMUM_PAN > 0.0f) ? HH_PANNING_MAXIMUM_PAN : self.bounds.size.width - self.panOffset;
            NSInteger directionMask = self.directionMask;
            CGFloat leftLimit = (directionMask & HHPanningTableViewCellDirectionLeft) ? (-1.0 * width) : 0.0f;
            CGFloat rightLimit = (directionMask & HHPanningTableViewCellDirectionRight) ? width : 0.0f;
            
            if (containerViewFrame.origin.x <= leftLimit) {
                containerViewFrame.origin.x = leftLimit;
            }
            else if (containerViewFrame.origin.x >= rightLimit) {
                containerViewFrame.origin.x = rightLimit;
            }
            
            [containerView setFrame:containerViewFrame];
        }
        else if ((state == UIGestureRecognizerStateEnded) || (state == UIGestureRecognizerStateCancelled)) {
            BOOL drawerRevealed = self.drawerRevealed;
            BOOL drawerWasRevealed = drawerRevealed;
            
            CGPoint translation = [gestureRecognizer translationInView:self];
            CGFloat totalPanX = translation.x;
            CGFloat panOriginX = self.panOriginX;
            BOOL isOffsetRight = (panOriginX > 0.0);
            HHPanningTableViewCellDirection panDirection = (totalPanX > 0.0f) ? HHPanningTableViewCellDirectionRight : HHPanningTableViewCellDirectionLeft;
            HHPanningTableViewCellDirection normalizedPanDirection = drawerRevealed ? HHOppositeDirection(panDirection) : panDirection;
            NSInteger directionMask = self.directionMask;
            
            if (drawerRevealed) {
                directionMask = isOffsetRight ? HHPanningTableViewCellDirectionRight : HHPanningTableViewCellDirectionLeft;
            }
            
            if (normalizedPanDirection & directionMask) {
                CGFloat triggerOffset = HH_PANNING_TRIGGER_OFFSET;
                
                if (fabsf(totalPanX) > triggerOffset) {
                    drawerRevealed = !drawerRevealed;
                }
                else if (HH_PANNING_USE_VELOCITY) {
                    CGPoint velocity = [gestureRecognizer velocityInView:self];
                    CGFloat velocityX = velocity.x;
                    
                    if (fabsf(velocityX) > triggerOffset) {
                        drawerRevealed = !drawerRevealed;
                    }
                }
            }
            
            HHPanningTableViewCellDirection direction = panDirection;
            
            if (drawerRevealed == drawerWasRevealed) {
                direction = isOffsetRight ? HHPanningTableViewCellDirectionRight : HHPanningTableViewCellDirectionLeft;
            }
            else {
                [self setDrawerRevealed:drawerRevealed direction:direction animated:YES];
            }
            
            self.panning = NO;
        }
    }
}

- (void)layoutSubviews
{
	[super layoutSubviews];
    
    if (self.isPanning) {
        return;
    }
    
	UIView* cellView = self;
	UIView* containerView = self.containerView;
	UIView* drawerView = self.drawerView;
	UIView* shadowView = self.shadowView;
	UIView* backgroundView = self.backgroundView;
	UIView* accessoryView = self.accessoryView;
	UIView* contentView = self.contentView;
    
	if (!self.animationInProgress) {
		CGRect cellBounds = [cellView bounds];
        CGRect containerFrame = [containerView frame];
        
        containerFrame.size.height = cellBounds.size.height;
        containerFrame.size.width = cellBounds.size.width;
        
		if (self.drawerRevealed) {
			if (containerFrame.origin.x > cellBounds.origin.x) {
				containerFrame.origin.x = cellBounds.origin.x + cellBounds.size.width - self.panOffset;
			}
			else {
				containerFrame.origin.x = cellBounds.origin.x - cellBounds.size.width + self.panOffset;
			}
			
			[containerView setFrame:containerFrame];
			
			[containerView addSubview:backgroundView];
			[containerView addSubview:accessoryView];
			[containerView addSubview:contentView];
            
			[self insertSubview:drawerView belowSubview:containerView];
			[self insertSubview:shadowView aboveSubview:drawerView];
		}
		else {
			[containerView setFrame:containerFrame];
			[containerView addSubview:backgroundView];
			[containerView addSubview:accessoryView];
			[containerView addSubview:contentView];
			
			[self addSubview:containerView];
		}
	}
	
	// Move other subviews. E.g. drag reorder control
	for (UIView *subview in [self.subviews reverseObjectEnumerator]) {
		if (subview == containerView) {
			continue;
		}
		
		if (subview == drawerView) {
			continue;
		}
		
		if (subview == shadowView) {
			continue;
		}
		
		if (subview == backgroundView) {
			continue;
		}
        
		if (subview == accessoryView) {
			continue;
		}
        
		if (subview == contentView) {
			continue;
		}
		
		[containerView insertSubview:subview atIndex:0];
	}
    
	//[drawerView setFrame:[cellView.bo bounds]];
    
	[self updateShadowFrame];
}

- (void)updateShadowFrame
{
	UIView* cellView = self;
	CGRect cellBounds = [cellView bounds];
	UIView* shadowView = self.shadowView;
	CGRect shadowFrame = self.drawerView.frame;
	
	//shadowFrame.size.width *= 2.0;
	
	if (self.drawerView.frame.origin.x < cellBounds.origin.x) {
        shadowFrame.origin.x = self.drawerView.frame.origin.x + self.drawerView.frame.size.width;
	}
	else {
        shadowFrame.origin.x = self.drawerView.frame.origin.x;
	}
    
	[shadowView setFrame:shadowFrame];
}

///////////////////////////////////////////////////////////
#pragma mark -
#pragma mark - UIView
///////////////////////////////////////////////////////////


///////////////////////////////////////////////////////////
#pragma mark -
#pragma mark - HHPanningTableViewCell
///////////////////////////////////////////////////////////

- (void)setDrawerRevealed:(BOOL)drawerRevealed {
    if (_drawerRevealed != drawerRevealed) {
        if ([self.superview isKindOfClass:[UITableView class]]) {
            for (UITableViewCell *cell in [(UITableView*)self.superview visibleCells]) {
                if ((cell != self) && [cell isKindOfClass:[HHPanningTableViewCell class]]) {
                    [(HHPanningTableViewCell*)cell setDrawerRevealed:NO animated:YES];
                }
            }
        }
        if ([self.delegate respondsToSelector:@selector(panningTableViewCell:didChangeDrawerRevealed:)]) {
            [self.delegate panningTableViewCell:self didChangeDrawerRevealed:drawerRevealed];
        }
        _drawerRevealed = drawerRevealed;
    }
}

@end

///////////////////////////////////////////////////////////
#pragma mark -
#pragma mark - static methods
///////////////////////////////////////////////////////////

static HHPanningTableViewCellDirection HHOppositeDirection(HHPanningTableViewCellDirection direction)
{
	switch (direction) {
		case HHPanningTableViewCellDirectionRight:
			return HHPanningTableViewCellDirectionLeft;
		case HHPanningTableViewCellDirectionLeft:
			return HHPanningTableViewCellDirectionRight;
	}
}
