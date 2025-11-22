//
//  SCMapLibreMapView.m
//  OmniTAK Mobile - MapLibre GL Native Integration
//
//  Implementation of MapLibre wrapper for Valdi framework.
//

#import "SCMapLibreMapView.h"
#import "valdi_core/SCValdiAttributesBinderBase.h"
#import "valdi_core/SCValdiAnimatorProtocol.h"
#import "valdi_core/SCValdiViewLayoutAttributes.h"

@import MapLibre;

@interface SCMapLibreMapView ()

@property (nonatomic, strong, readwrite) MLNMapView *mapView;
@property (nonatomic, strong) NSMutableDictionary<NSString *, MLNPointAnnotation *> *annotationsById;
@property (nonatomic, copy, nullable) void (^onMapReadyCallback)(void);
@property (nonatomic, copy, nullable) void (^onMarkerTapCallback)(NSString *markerId);
@property (nonatomic, copy, nullable) void (^onMapTapCallback)(NSDictionary *position);
@property (nonatomic, copy, nullable) void (^onCameraChangedCallback)(NSDictionary *camera);
@property (nonatomic, assign) BOOL mapIsReady;

@end

@implementation SCMapLibreMapView

#pragma mark - Initialization

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupDefaults];
        [self setupMapView];
    }
    return self;
}

- (void)setupDefaults {
    _annotationsById = [NSMutableDictionary dictionary];
    // Use MapTiler's free OSM Bright style - no satellite warnings
    // Alternative: https://demotiles.maplibre.org/style.json
    _styleURL = @"https://tiles.openfreemap.org/styles/liberty";
    _userInteractionEnabled = YES;
    _showUserLocation = NO;
    _mapIsReady = NO;
}

- (void)setupMapView {
    // Don't create map view with zero bounds - wait for first layout
    // This prevents "clip: empty path" and CAMetalLayer warnings
    if (CGRectIsEmpty(self.bounds) || self.bounds.size.width == 0 || self.bounds.size.height == 0) {
        return;
    }

    // Initialize MapLibre map view with default style
    NSURL *styleURL = [NSURL URLWithString:self.styleURL];
    _mapView = [[MLNMapView alloc] initWithFrame:self.bounds styleURL:styleURL];
    _mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _mapView.delegate = self;
    _mapView.userInteractionEnabled = self.userInteractionEnabled;
    _mapView.showsUserLocation = self.showUserLocation;

    // Default camera position (centered on US)
    _mapView.centerCoordinate = CLLocationCoordinate2DMake(39.8283, -98.5795);
    _mapView.zoomLevel = 4.0;

    [self addSubview:_mapView];
}

#pragma mark - View Lifecycle

- (void)layoutSubviews {
    [super layoutSubviews];

    // If map view hasn't been created yet (because initial bounds were zero), create it now
    if (!_mapView && !CGRectIsEmpty(self.bounds) && self.bounds.size.width > 0 && self.bounds.size.height > 0) {
        [self setupMapView];
    }

    _mapView.frame = self.bounds;
}

- (BOOL)willEnqueueIntoValdiPool {
    // Support view pooling for performance
    // Clean up before recycling
    [self cleanup];
    return YES;
}

- (void)cleanup {
    // Remove all annotations
    if (_mapView.annotations) {
        [_mapView removeAnnotations:_mapView.annotations];
    }
    [_annotationsById removeAllObjects];

    // Clear callbacks
    _onMapReadyCallback = nil;
    _onMarkerTapCallback = nil;
    _onMapTapCallback = nil;
    _onCameraChangedCallback = nil;

    _mapIsReady = NO;
}

- (void)dealloc {
    _mapView.delegate = nil;
    [self cleanup];
}

#pragma mark - Valdi Attribute Setters

- (BOOL)valdi_setOptions:(NSDictionary *)options {
    if (![options isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    // Apply style URL if provided
    NSString *style = options[@"style"];
    if (style && [style isKindOfClass:[NSString class]]) {
        self.styleURL = style;
        NSURL *styleURL = [NSURL URLWithString:style];
        if (styleURL) {
            _mapView.styleURL = styleURL;
        }
    }

    // Apply interaction settings
    if (options[@"interactive"] != nil) {
        self.userInteractionEnabled = [options[@"interactive"] boolValue];
        _mapView.userInteractionEnabled = self.userInteractionEnabled;
    }

    // Apply user location visibility
    if (options[@"showUserLocation"] != nil) {
        self.showUserLocation = [options[@"showUserLocation"] boolValue];
        _mapView.showsUserLocation = self.showUserLocation;
    }

    // Apply compass visibility
    if (options[@"showCompass"] != nil) {
        _mapView.compassView.hidden = ![options[@"showCompass"] boolValue];
    }

    // Apply scale bar visibility
    if (options[@"showScaleBar"] != nil) {
        _mapView.scaleBar.hidden = ![options[@"showScaleBar"] boolValue];
    }

    return YES;
}

- (BOOL)valdi_setCamera:(NSDictionary *)camera {
    if (![camera isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    // Extract camera parameters
    NSNumber *lat = camera[@"latitude"];
    NSNumber *lon = camera[@"longitude"];
    NSNumber *zoom = camera[@"zoom"];
    NSNumber *bearing = camera[@"bearing"];
    NSNumber *pitch = camera[@"pitch"];
    NSNumber *animated = camera[@"animated"];

    if (!lat || !lon) {
        return NO;
    }

    CLLocationCoordinate2D center = CLLocationCoordinate2DMake([lat doubleValue], [lon doubleValue]);

    // Create camera
    MLNMapCamera *newCamera = [MLNMapCamera cameraLookingAtCenterCoordinate:center
                                                              acrossDistance:1000
                                                                       pitch:pitch ? [pitch doubleValue] : 0
                                                                     heading:bearing ? [bearing doubleValue] : 0];

    // Apply camera with optional animation
    BOOL shouldAnimate = animated ? [animated boolValue] : NO;
    if (shouldAnimate) {
        [_mapView setCamera:newCamera animated:YES];
    } else {
        _mapView.camera = newCamera;
    }

    // Apply zoom level separately
    if (zoom) {
        if (shouldAnimate) {
            [_mapView setZoomLevel:[zoom doubleValue] animated:YES];
        } else {
            _mapView.zoomLevel = [zoom doubleValue];
        }
    }

    return YES;
}

- (BOOL)valdi_setMarkers:(NSArray *)markers {
    if (![markers isKindOfClass:[NSArray class]]) {
        return NO;
    }

    // Track which markers should exist
    NSMutableSet<NSString *> *newMarkerIds = [NSMutableSet set];
    NSMutableArray<MLNPointAnnotation *> *annotationsToAdd = [NSMutableArray array];

    for (NSDictionary *markerData in markers) {
        if (![markerData isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSString *markerId = markerData[@"id"];
        NSNumber *lat = markerData[@"latitude"];
        NSNumber *lon = markerData[@"longitude"];

        if (!markerId || !lat || !lon) {
            continue;
        }

        [newMarkerIds addObject:markerId];

        // Check if marker already exists
        MLNPointAnnotation *existingAnnotation = _annotationsById[markerId];
        if (existingAnnotation) {
            // Update position if changed
            CLLocationCoordinate2D newCoord = CLLocationCoordinate2DMake([lat doubleValue], [lon doubleValue]);
            if (existingAnnotation.coordinate.latitude != newCoord.latitude ||
                existingAnnotation.coordinate.longitude != newCoord.longitude) {
                existingAnnotation.coordinate = newCoord;
            }

            // Update title if provided
            NSString *title = markerData[@"title"];
            if (title && [title isKindOfClass:[NSString class]]) {
                existingAnnotation.title = title;
            }

            // Update subtitle if provided
            NSString *subtitle = markerData[@"subtitle"];
            if (subtitle && [subtitle isKindOfClass:[NSString class]]) {
                existingAnnotation.subtitle = subtitle;
            }
        } else {
            // Create new annotation
            MLNPointAnnotation *annotation = [[MLNPointAnnotation alloc] init];
            annotation.coordinate = CLLocationCoordinate2DMake([lat doubleValue], [lon doubleValue]);

            NSString *title = markerData[@"title"];
            if (title && [title isKindOfClass:[NSString class]]) {
                annotation.title = title;
            }

            NSString *subtitle = markerData[@"subtitle"];
            if (subtitle && [subtitle isKindOfClass:[NSString class]]) {
                annotation.subtitle = subtitle;
            }

            _annotationsById[markerId] = annotation;
            [annotationsToAdd addObject:annotation];
        }
    }

    // Remove markers that are no longer in the list
    NSMutableArray<MLNPointAnnotation *> *annotationsToRemove = [NSMutableArray array];
    for (NSString *existingId in [_annotationsById allKeys]) {
        if (![newMarkerIds containsObject:existingId]) {
            MLNPointAnnotation *annotation = _annotationsById[existingId];
            [annotationsToRemove addObject:annotation];
            [_annotationsById removeObjectForKey:existingId];
        }
    }

    // Apply changes to map
    if (annotationsToRemove.count > 0) {
        [_mapView removeAnnotations:annotationsToRemove];
    }
    if (annotationsToAdd.count > 0) {
        [_mapView addAnnotations:annotationsToAdd];
    }

    return YES;
}

- (BOOL)valdi_setOnMapReady:(void (^)(void))callback {
    _onMapReadyCallback = [callback copy];

    // If map is already ready, call immediately
    if (_mapIsReady && callback) {
        callback();
    }

    return YES;
}

- (BOOL)valdi_setOnMarkerTap:(void (^)(NSString *))callback {
    _onMarkerTapCallback = [callback copy];
    return YES;
}

- (BOOL)valdi_setOnMapTap:(void (^)(NSDictionary *))callback {
    _onMapTapCallback = [callback copy];
    return YES;
}

- (BOOL)valdi_setOnCameraChanged:(void (^)(NSDictionary *))callback {
    _onCameraChangedCallback = [callback copy];
    return YES;
}

#pragma mark - MLNMapViewDelegate

- (void)mapViewDidFinishLoadingMap:(MLNMapView *)mapView {
    _mapIsReady = YES;

    if (_onMapReadyCallback) {
        _onMapReadyCallback();
    }
}

- (void)mapView:(MLNMapView *)mapView didSelectAnnotation:(id<MLNAnnotation>)annotation {
    // Find marker ID by annotation
    for (NSString *markerId in _annotationsById) {
        if (_annotationsById[markerId] == annotation) {
            if (_onMarkerTapCallback) {
                _onMarkerTapCallback(markerId);
            }
            break;
        }
    }
}

- (void)mapView:(MLNMapView *)mapView didUpdateUserLocation:(nullable MLNUserLocation *)userLocation {
    // User location updated - could forward to TypeScript if needed
}

- (void)mapView:(MLNMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    if (_onCameraChangedCallback) {
        NSDictionary *cameraInfo = @{
            @"latitude": @(mapView.centerCoordinate.latitude),
            @"longitude": @(mapView.centerCoordinate.longitude),
            @"zoom": @(mapView.zoomLevel),
            @"bearing": @(mapView.camera.heading),
            @"pitch": @(mapView.camera.pitch),
            @"animated": @(animated)
        };
        _onCameraChangedCallback(cameraInfo);
    }
}

- (BOOL)mapView:(MLNMapView *)mapView annotationCanShowCallout:(id<MLNAnnotation>)annotation {
    // Enable callouts for all annotations
    return YES;
}

// Customize annotation view appearance
- (nullable MLNAnnotationView *)mapView:(MLNMapView *)mapView viewForAnnotation:(id<MLNAnnotation>)annotation {
    if (![annotation isKindOfClass:[MLNPointAnnotation class]]) {
        return nil;
    }

    // Reuse annotation views for performance
    static NSString *reuseIdentifier = @"com.engindearing.omnitak.marker";
    MLNAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:reuseIdentifier];

    if (!annotationView) {
        annotationView = [[MLNAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
        annotationView.frame = CGRectMake(0, 0, 30, 30);

        // Create default marker icon
        UIView *markerView = [[UIView alloc] initWithFrame:annotationView.bounds];
        markerView.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
        markerView.layer.cornerRadius = 15;
        markerView.layer.borderWidth = 2;
        markerView.layer.borderColor = [UIColor whiteColor].CGColor;
        [annotationView addSubview:markerView];

        // Center the marker on the coordinate
        annotationView.centerOffset = CGVectorMake(0, -annotationView.frame.size.height / 2);
    } else {
        annotationView.annotation = annotation;
    }

    return annotationView;
}

#pragma mark - Valdi Attributes Binding

+ (void)bindAttributes:(id<SCValdiAttributesBinderProtocol>)attributesBinder {
    // Bind 'options' attribute (JSON object)
    [attributesBinder bindAttribute:@"options"
           invalidateLayoutOnChange:NO
                   withUntypedBlock:^BOOL(__kindof SCMapLibreMapView *view,
                                         id attributeValue,
                                         id<SCValdiAnimatorProtocol> animator) {
        if ([attributeValue isKindOfClass:[NSDictionary class]]) {
            return [view valdi_setOptions:attributeValue];
        }
        return NO;
    }
                         resetBlock:^(__kindof SCMapLibreMapView *view,
                                     id<SCValdiAnimatorProtocol> animator) {
        // Reset to defaults
        [view valdi_setOptions:@{}];
    }];

    // Bind 'camera' attribute (JSON object)
    [attributesBinder bindAttribute:@"camera"
           invalidateLayoutOnChange:NO
                   withUntypedBlock:^BOOL(__kindof SCMapLibreMapView *view,
                                         id attributeValue,
                                         id<SCValdiAnimatorProtocol> animator) {
        if ([attributeValue isKindOfClass:[NSDictionary class]]) {
            return [view valdi_setCamera:attributeValue];
        }
        return NO;
    }
                         resetBlock:^(__kindof SCMapLibreMapView *view,
                                     id<SCValdiAnimatorProtocol> animator) {
        // Reset to default camera
        NSDictionary *defaultCamera = @{
            @"latitude": @(39.8283),
            @"longitude": @(-98.5795),
            @"zoom": @(4.0)
        };
        [view valdi_setCamera:defaultCamera];
    }];

    // Bind 'markers' attribute (JSON array)
    [attributesBinder bindAttribute:@"markers"
           invalidateLayoutOnChange:NO
                   withUntypedBlock:^BOOL(__kindof SCMapLibreMapView *view,
                                         id attributeValue,
                                         id<SCValdiAnimatorProtocol> animator) {
        if ([attributeValue isKindOfClass:[NSArray class]]) {
            return [view valdi_setMarkers:attributeValue];
        }
        return NO;
    }
                         resetBlock:^(__kindof SCMapLibreMapView *view,
                                     id<SCValdiAnimatorProtocol> animator) {
        [view valdi_setMarkers:@[]];
    }];

    // Bind callback attributes
    [attributesBinder bindAttribute:@"onMapReady"
           invalidateLayoutOnChange:NO
                   withUntypedBlock:^BOOL(__kindof SCMapLibreMapView *view,
                                         id attributeValue,
                                         id<SCValdiAnimatorProtocol> animator) {
        if ([attributeValue isKindOfClass:NSClassFromString(@"NSBlock")]) {
            return [view valdi_setOnMapReady:attributeValue];
        }
        return NO;
    }
                         resetBlock:^(__kindof SCMapLibreMapView *view,
                                     id<SCValdiAnimatorProtocol> animator) {
        [view valdi_setOnMapReady:nil];
    }];

    [attributesBinder bindAttribute:@"onMarkerTap"
           invalidateLayoutOnChange:NO
                   withUntypedBlock:^BOOL(__kindof SCMapLibreMapView *view,
                                         id attributeValue,
                                         id<SCValdiAnimatorProtocol> animator) {
        if ([attributeValue isKindOfClass:NSClassFromString(@"NSBlock")]) {
            return [view valdi_setOnMarkerTap:attributeValue];
        }
        return NO;
    }
                         resetBlock:^(__kindof SCMapLibreMapView *view,
                                     id<SCValdiAnimatorProtocol> animator) {
        [view valdi_setOnMarkerTap:nil];
    }];

    [attributesBinder bindAttribute:@"onMapTap"
           invalidateLayoutOnChange:NO
                   withUntypedBlock:^BOOL(__kindof SCMapLibreMapView *view,
                                         id attributeValue,
                                         id<SCValdiAnimatorProtocol> animator) {
        if ([attributeValue isKindOfClass:NSClassFromString(@"NSBlock")]) {
            return [view valdi_setOnMapTap:attributeValue];
        }
        return NO;
    }
                         resetBlock:^(__kindof SCMapLibreMapView *view,
                                     id<SCValdiAnimatorProtocol> animator) {
        [view valdi_setOnMapTap:nil];
    }];

    [attributesBinder bindAttribute:@"onCameraChanged"
           invalidateLayoutOnChange:NO
                   withUntypedBlock:^BOOL(__kindof SCMapLibreMapView *view,
                                         id attributeValue,
                                         id<SCValdiAnimatorProtocol> animator) {
        if ([attributeValue isKindOfClass:NSClassFromString(@"NSBlock")]) {
            return [view valdi_setOnCameraChanged:attributeValue];
        }
        return NO;
    }
                         resetBlock:^(__kindof SCMapLibreMapView *view,
                                     id<SCValdiAnimatorProtocol> animator) {
        [view valdi_setOnCameraChanged:nil];
    }];

    // Map view should fill available space
    [attributesBinder setMeasureDelegate:^CGSize(id<SCValdiViewLayoutAttributes> attributes,
                                                 CGSize maxSize,
                                                 UITraitCollection *traitCollection) {
        return maxSize;
    }];
}

@end
