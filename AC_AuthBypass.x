// Animal Company Auth Bypass - Skip 403 Error
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Hook common authentication classes
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    
    NSString *url = request.URL.absoluteString;
    
    // Check if this is an auth/login request
    if ([url containsString:@"api"] || [url containsString:@"auth"] || [url containsString:@"login"]) {
        NSLog(@"[AuthBypass] Intercepted auth request: %@", url);
        
        // Create fake success response
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *fakeResponse = @{
                @"success": @YES,
                @"status": @"ok",
                @"authenticated": @YES,
                @"user": @{
                    @"id": @"offline_user",
                    @"name": @"Offline Player"
                }
            };
            
            NSData *fakeData = [NSJSONSerialization dataWithJSONObject:fakeResponse options:0 error:nil];
            NSHTTPURLResponse *fakeHTTPResponse = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type": @"application/json"}];
            
            completionHandler(fakeData, fakeHTTPResponse, nil);
        });
        
        // Return dummy task
        return [self dataTaskWithURL:[NSURL URLWithString:@"about:blank"]];
    }
    
    // For other requests, proceed normally
    return %orig;
}

%end

%hook NSURLConnection

+ (void)sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *connectionError))handler {
    
    NSString *url = request.URL.absoluteString;
    
    if ([url containsString:@"api"] || [url containsString:@"auth"] || [url containsString:@"login"]) {
        NSLog(@"[AuthBypass] Intercepted NSURLConnection auth request: %@", url);
        
        NSDictionary *fakeResponse = @{@"success": @YES, @"authenticated": @YES};
        NSData *fakeData = [NSJSONSerialization dataWithJSONObject:fakeResponse options:0 error:nil];
        NSHTTPURLResponse *fakeHTTPResponse = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type": @"application/json"}];
        
        dispatch_async(queue, ^{
            handler(fakeHTTPResponse, fakeData, nil);
        });
        
        return;
    }
    
    %orig;
}

%end

// Hook HTTP response errors
%hook NSHTTPURLResponse

- (NSInteger)statusCode {
    NSInteger code = %orig;
    
    // If it's a 403, change it to 200
    if (code == 403) {
        NSLog(@"[AuthBypass] Bypassed 403 error!");
        return 200;
    }
    
    return code;
}

%end

// Hook NSError to suppress auth errors
%hook NSError

+ (instancetype)errorWithDomain:(NSErrorDomain)domain code:(NSInteger)code userInfo:(NSDictionary *)dict {
    
    // Suppress 403 errors
    if (code == 403) {
        NSLog(@"[AuthBypass] Suppressed 403 NSError");
        return nil;
    }
    
    return %orig;
}

%end

%ctor {
    NSLog(@"[AuthBypass] ✅ Animal Company Auth Bypass loaded - 403 errors will be bypassed");
}
