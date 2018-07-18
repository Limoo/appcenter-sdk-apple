#import <Foundation/Foundation.h>

#import "MSAnalyticsTransmissionTarget.h"
#import "MSPropertyConfigurator.h"
#import "MSUtility.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSAnalyticsTransmissionTarget ()

/**
 * Parent transmission target of this target.
 */
@property(nonatomic, nullable) MSAnalyticsTransmissionTarget *parentTarget;

/**
 * Event properties attached to events tracked by this target.
 */
@property(nonatomic, nullable) NSMutableDictionary<NSString *, NSString *> *eventProperties;

/**
 * Child transmission targets nested to this transmission target.
 */
@property(nonatomic) NSMutableDictionary<NSString *, MSAnalyticsTransmissionTarget *> *childTransmissionTargets;

/**
 * isEnabled value storage key.
 */
@property(nonatomic, readonly) NSString *isEnabledKey;

/**
 * The channel group.
 */
@property(nonatomic) id<MSChannelProtocol> channelGroup;

/**
 * Property configurator.
 */
@property(nonatomic, readonly) MSPropertyConfigurator *propertyConfigurator;

@end

NS_ASSUME_NONNULL_END
