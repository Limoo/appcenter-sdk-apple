// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSHttpIngestion.h"
#import "MSAppCenterInternal.h"
#import "MSHttpIngestionPrivate.h"
#import "MSUtility+StringFormatting.h"

//static NSTimeInterval kRequestTimeout = 60.0;

// URL components' name within a partial URL.
static NSString *const kMSPartialURLComponentsName[] = {@"scheme", @"user", @"password", @"host", @"port", @"path"};

@implementation MSHttpIngestion

@synthesize baseURL = _baseURL;
@synthesize apiPath = _apiPath;

#pragma mark - Initialize

- (id)initWithHttpClient:(id<MSHttpClientProtocol>)httpClient
                 baseUrl:(NSString *)baseUrl
              apiPath:(NSString *)apiPath
              headers:(NSDictionary *)headers
         queryStrings:(NSDictionary *)queryStrings {
  return [self initWithHttpClient:httpClient
                          baseUrl:baseUrl
                       apiPath:apiPath
                       headers:headers
                  queryStrings:queryStrings
                retryIntervals:@[ @(10), @(5 * 60), @(20 * 60) ]];
}

- (id)initWithHttpClient:(id<MSHttpClientProtocol>)httpClient
                 baseUrl:(NSString *)baseUrl
              apiPath:(NSString *)apiPath
              headers:(NSDictionary *)headers
         queryStrings:(NSDictionary *)queryStrings
       retryIntervals:(NSArray *)retryIntervals {
  return [self initWithHttpClient:httpClient
                          baseUrl:baseUrl
                       apiPath:apiPath
                       headers:headers
                  queryStrings:queryStrings
                retryIntervals:retryIntervals
        maxNumberOfConnections:4];
}

- (id)initWithHttpClient:(id<MSHttpClientProtocol>)httpClient
                 baseUrl:(NSString *)baseUrl
                   apiPath:(NSString *)apiPath
                   headers:(NSDictionary *)headers
              queryStrings:(NSDictionary *)queryStrings
            retryIntervals:(NSArray *)retryIntervals
    maxNumberOfConnections:(NSInteger)maxNumberOfConnections {
  if ((self = [super init])) {
    _httpHeaders = headers;
    _httpClient = httpClient;
    _enabled = YES;
//    _delegates = [NSHashTable weakObjectsHashTable];
    _callsRetryIntervals = retryIntervals;
    _apiPath = apiPath;
    _maxNumberOfConnections = maxNumberOfConnections;
    _baseURL = baseUrl;

    // Construct the URL string with the query string.
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@%@", baseUrl, apiPath];
    __block NSMutableString *queryStringForEncoding = [NSMutableString new];

    // Set query parameter.
    [queryStrings enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull queryString, __unused BOOL *_Nonnull stop) {
      [queryStringForEncoding
          appendString:[NSString stringWithFormat:@"%@%@=%@", [queryStringForEncoding length] > 0 ? @"&" : @"", key, queryString]];
    }];
    if ([queryStringForEncoding length] > 0) {
      [urlString appendFormat:@"?%@", [queryStringForEncoding
                                          stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    }

    // Set send URL which can't be null
    _sendURL = (NSURL * _Nonnull)[NSURL URLWithString:urlString];
  }
  return self;
}

#pragma mark - MSIngestion

- (BOOL)isReadyToSend {
  return YES;
}

- (void)sendAsync:(NSObject *)data authToken:(nullable NSString *)authToken completionHandler:(MSSendAsyncCompletionHandler)handler {
  [self sendAsync:data eTag:nil authToken:authToken callId:MS_UUID_STRING completionHandler:handler];
}

- (void)sendAsync:(NSObject *)data
                 eTag:(nullable NSString *)eTag
            authToken:(nullable NSString *)authToken
    completionHandler:(MSSendAsyncCompletionHandler)handler {
  [self sendAsync:data eTag:eTag authToken:authToken callId:MS_UUID_STRING completionHandler:handler];
}

- (void)sendAsync:(NSObject *)data completionHandler:(MSSendAsyncCompletionHandler)handler {
  [self sendAsync:data eTag:nil authToken:nil callId:MS_UUID_STRING completionHandler:handler];
}

- (void)sendAsync:(NSObject *)data eTag:(nullable NSString *)eTag completionHandler:(MSSendAsyncCompletionHandler)handler {
  [self sendAsync:data eTag:eTag authToken:nil callId:MS_UUID_STRING completionHandler:handler];
}

//- (void)addDelegate:(id<MSIngestionDelegate>)delegate {
//  @synchronized(self) {
//    [self.delegates addObject:delegate];
//  }
//}
//
//- (void)removeDelegate:(id<MSIngestionDelegate>)delegate {
//  @synchronized(self) {
//    [self.delegates removeObject:delegate];
//  }
//}

#pragma mark - Life cycle

- (void)setEnabled:(BOOL)isEnabled andDeleteDataOnDisabled:(BOOL)deleteData {
//TODO figure this out.
  (void)isEnabled;
  (void)deleteData;
}

#pragma mark - MSIngestionCallDelegate

- (void) prettyPrintRequest {
  //TODO do
  /*
  // Don't lose time pretty printing if not going to be printed.
  if ([MSAppCenter logLevel] <= MSLogLevelVerbose) {
    NSString *contentType = httpResponse.allHeaderFields[kMSHeaderContentTypeKey];
    NSString *payload;

    // Obfuscate payload.
    if (data.length > 0) {
      if ([contentType hasPrefix:@"application/json"]) {
        payload = [MSUtility obfuscateString:[MSUtility prettyPrintJson:data]
                         searchingForPattern:kMSTokenKeyValuePattern
                       toReplaceWithTemplate:kMSTokenKeyValueObfuscatedTemplate];
        payload = [MSUtility obfuscateString:payload
                         searchingForPattern:kMSRedirectUriPattern
                       toReplaceWithTemplate:kMSRedirectUriObfuscatedTemplate];
      } else if (!contentType.length || [contentType hasPrefix:@"text/"] || [contentType hasPrefix:@"application/"]) {
        payload = [MSUtility obfuscateString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
                         searchingForPattern:kMSTokenKeyValuePattern
                       toReplaceWithTemplate:kMSTokenKeyValueObfuscatedTemplate];
        payload = [MSUtility obfuscateString:payload
                         searchingForPattern:kMSRedirectUriPattern
                       toReplaceWithTemplate:kMSRedirectUriObfuscatedTemplate];
      } else {
        payload = @"<binary>";
      }
    }
    MSLogVerbose([MSAppCenter logTag], @"HTTP response received with status code: %tu, payload:\n%@", httpResponse.statusCode,
                 payload);
  }*/
}

#pragma mark - Private

- (void)setBaseURL:(NSString *)baseURL {
  @synchronized(self) {
    BOOL success = false;
    NSURLComponents *components;
    _baseURL = baseURL;
    NSURL *partialURL = [NSURL URLWithString:[baseURL stringByAppendingString:self.apiPath]];

    // Merge new parial URL and current full URL.
    if (partialURL) {
      components = [NSURLComponents componentsWithURL:self.sendURL resolvingAgainstBaseURL:NO];
      @try {
        for (u_long i = 0; i < sizeof(kMSPartialURLComponentsName) / sizeof(*kMSPartialURLComponentsName); i++) {
          NSString *propertyName = kMSPartialURLComponentsName[i];
          [components setValue:[partialURL valueForKey:propertyName] forKey:propertyName];
        }
      } @catch (NSException *ex) {
        MSLogInfo([MSAppCenter logTag], @"Error while updating HTTP URL %@ with %@: \n%@", self.sendURL.absoluteString, baseURL, ex);
      }

      // Update full URL.
      if (components.URL) {
        self.sendURL = (NSURL * _Nonnull) components.URL;
        success = true;
      }
    }

    // Notify failure.
    if (!success) {
      MSLogInfo([MSAppCenter logTag], @"Failed to update HTTP URL %@ with %@", self.sendURL.absoluteString, baseURL);
    }
  }
}

/**
 * This is an empty method expected to be overridden in sub classes.
 */
- (NSURLRequest *)createRequest:(NSObject *)__unused data eTag:(NSString *)__unused eTag authToken:(nullable NSString *)__unused authToken {
  return nil;
}

- (NSString *)obfuscateHeaderValue:(NSString *)value forKey:(NSString *)key {
  (void)key;
  return value;
}

- (NSString *)prettyPrintHeaders:(NSDictionary<NSString *, NSString *> *)headers {
  NSMutableArray<NSString *> *flattenedHeaders = [NSMutableArray<NSString *> new];
  for (NSString *headerKey in headers) {
    [flattenedHeaders
        addObject:[NSString stringWithFormat:@"%@ = %@", headerKey, [self obfuscateHeaderValue:headers[headerKey] forKey:headerKey]]];
  }
  return [flattenedHeaders componentsJoinedByString:@", "];
}

- (void)sendAsync:(NSObject * __unused)data
                 eTag:(nullable NSString * __unused)eTag
            authToken:(nullable NSString * __unused)authToken
               callId:(NSString * __unused)callId
    completionHandler:(MSSendAsyncCompletionHandler __unused)handler {
  // TODO this will be overridden?
}

#pragma mark - Helper

+ (nullable NSString *)eTagFromResponse:(NSHTTPURLResponse *)response {

  // Response header keys are case-insensitive but NSHTTPURLResponse contains case-sensitive keys in Dictionary.
  for (NSString *key in response.allHeaderFields.allKeys) {
    if ([[key lowercaseString] isEqualToString:kMSETagResponseHeader]) {
      return response.allHeaderFields[key];
    }
  }
  return nil;
}

@end
