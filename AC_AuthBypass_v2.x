// Animal Company Auth Bypass v2 - Aggressive patches
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Patch ALL HTTP responses to never return 403
%hook NSHTTPURLResponse

- (instancetype)initWithURL:(NSURL *)url statusCode:(NSInteger)statusCode HTTPVersion:(NSString *)HTTPVersion headerFields:(NSDictionary<NSString *,NSString *> *)headerFields {
    if (statusCode == 403 || statusCode == 401 || statusCode == 400) {
        NSLog(@"[AuthBypass] Blocked status code %ld, changing to 200", (long)statusCode);
        return %orig(url, 200, HTTPVersion, headerFields);
    }
    return %orig;
}

- (NSInteger)statusCode {
    NSInteger code = %orig;
    if (code == 403 || code == 401 || code == 400) {
        NSLog(@"[AuthBypass] Returning 200 instead of %ld", (long)code);
        return 200;
    }
    return code;
}

%end

// Intercept ALL network requests
%hook NSURLSessionConfiguration

+ (NSURLSessionConfiguration *)defaultSessionConfiguration {
    NSURLSessionConfiguration *config = %orig;
    NSLog(@"[AuthBypass] Session configuration created");
    return config;
}

%end

// Block error creation
%hook NSError

+ (instancetype)errorWithDomain:(NSErrorDomain)domain code:(NSInteger)code userInfo:(NSDictionary *)dict {
    if (code == 403 || code == 401 || 
        [domain isEqualToString:NSURLErrorDomain] ||
        [domain containsString:@"Auth"] ||
        [domain containsString:@"Login"]) {
        NSLog(@"[AuthBypass] Blocked error: domain=%@ code=%ld", domain, (long)code);
        return nil;
    }
    return %orig;
}

- (NSInteger)code {
    NSInteger code = %orig;
    if (code == 403 || code == 401) {
        NSLog(@"[AuthBypass] Changed error code from %ld to 0", (long)code);
        return 0;
    }
    return code;
}

%end

// Try to find and hook Unity/IL2CPP network functions
static void (*original_il2cpp_raise_exception)(void*) = NULL;

void patched_il2cpp_raise_exception(void* exc) {
    NSLog(@"[AuthBypass] Blocked IL2CPP exception!");
    // Don't call original - just ignore exceptions
}

// Patch any class that might handle auth errors
%hook UIAlertController

+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(UIAlertControllerStyle)preferredStyle {
    // Block error alerts about login/auth
    if ([title containsString:@"Error"] || 
        [title containsString:@"Failed"] ||
        [message containsString:@"403"] ||
        [message containsString:@"forbidden"] ||
        [message containsString:@"UnhandledApiError"]) {
        NSLog(@"[AuthBypass] Blocked error alert: %@ - %@", title, message);
        return nil;
    }
    return %orig;
}

%end

// Hook UIViewController presentation to block error screens
%hook UIViewController

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    // Check if it's an error alert
    if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        UIAlertController *alert = (UIAlertController *)viewControllerToPresent;
        if ([alert.title containsString:@"Error"] || 
            [alert.message containsString:@"403"]) {
            NSLog(@"[AuthBypass] Blocked error presentation");
            if (completion) completion();
            return;
        }
    }
    %orig;
}

%end

// Try to hook app delegate for early initialization
%hook UIApplicationDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"[AuthBypass] App launched - applying patches");
    
    // Try to find il2cpp functions
    void *handle = dlopen(NULL, RTLD_NOW);
    if (handle) {
        original_il2cpp_raise_exception = dlsym(handle, "il2cpp_raise_exception");
        if (original_il2cpp_raise_exception) {
            MSHookFunction(original_il2cpp_raise_exception, (void*)patched_il2cpp_raise_exception, NULL);
            NSLog(@"[AuthBypass] Hooked il2cpp_raise_exception");
        }
    }
    
    return %orig;
}

%end

%ctor {
    NSLog(@"[AuthBypass] ================================");
    NSLog(@"[AuthBypass] Auth Bypass v2 LOADED");
    NSLog(@"[AuthBypass] All 403/401/400 errors will be blocked");
    NSLog(@"[AuthBypass] Error alerts will be suppressed");
    NSLog(@"[AuthBypass] ================================");
}
