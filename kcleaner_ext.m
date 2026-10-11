#import "kcleaner_ext.h"
#import <string.h>
#import <unistd.h>

KCAction kc_action = KCActionDump;
NSString *kc_filterKeyword = nil;
NSString *kc_accessGroupFilter = nil;
NSString *kc_deleteKeyword = nil;
BOOL kc_jsonOutput = NO;

static void kc_print(NSString *format, ...) {
  va_list args;
  va_start(args, format);
  NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);
  [[NSFileHandle fileHandleWithStandardOutput] writeData:[formattedString dataUsingEncoding:NSUTF8StringEncoding]];
  [formattedString release];
}

static NSArray *kc_passwordSecClasses(void) {
  return [NSArray arrayWithObjects:(id)kSecClassGenericPassword, (id)kSecClassInternetPassword, nil];
}

static NSArray *kc_fetchItemsForClass(CFTypeRef kSecClassType) {
  NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
  [query setObject:(id)kSecClassType forKey:(id)kSecClass];
  [query setObject:(id)kSecMatchLimitAll forKey:(id)kSecMatchLimit];
  [query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
  [query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
  NSArray *items = nil;
  if (SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&items) != noErr) {
    items = nil;
  }
  [query release];
  return items;
}

static NSString *kc_stringField(NSDictionary *item, id key) {
  id value = [item objectForKey:key];
  if (!value || value == (id)kCFNull) {
    return @"";
  }
  if ([value isKindOfClass:[NSString class]]) {
    return (NSString *)value;
  }
  if ([value isKindOfClass:[NSData class]]) {
    NSString *utf8 = [[NSString alloc] initWithData:(NSData *)value encoding:NSUTF8StringEncoding];
    if (utf8) {
      NSString *copy = [utf8 copy];
      [utf8 release];
      return copy;
    }
    return @"";
  }
  return [value description];
}

static BOOL kc_containsKeyword(NSString *haystack, NSString *needle) {
  if (needle.length == 0) {
    return YES;
  }
  if (haystack.length == 0) {
    return NO;
  }
  return [haystack rangeOfString:needle options:NSCaseInsensitiveSearch].location != NSNotFound;
}

BOOL kc_itemPassesFilters(NSDictionary *item) {
  if (kc_accessGroupFilter.length > 0) {
    NSString *group = kc_stringField(item, (id)kSecAttrAccessGroup);
    if ([group rangeOfString:kc_accessGroupFilter options:NSCaseInsensitiveSearch].location == NSNotFound) {
      return NO;
    }
  }
  if (kc_filterKeyword.length == 0) {
    return YES;
  }
  NSArray *fields = @[
    kc_stringField(item, (id)kSecAttrService),
    kc_stringField(item, (id)kSecAttrAccount),
    kc_stringField(item, (id)kSecAttrServer),
    kc_stringField(item, (id)kSecAttrAccessGroup),
    kc_stringField(item, (id)kSecAttrLabel),
    kc_stringField(item, (id)kSecAttrDescription),
    kc_stringField(item, (id)kSecAttrComment),
  ];
  for (NSString *field in fields) {
    if (kc_containsKeyword(field, kc_filterKeyword)) {
      return YES;
    }
  }
  return NO;
}

static BOOL kc_itemMatchesDeleteKeyword(NSDictionary *item, NSString *keyword) {
  if (keyword.length == 0) {
    return NO;
  }
  NSArray *fields = @[
    kc_stringField(item, (id)kSecAttrService),
    kc_stringField(item, (id)kSecAttrAccount),
    kc_stringField(item, (id)kSecAttrServer),
    kc_stringField(item, (id)kSecAttrAccessGroup),
    kc_stringField(item, (id)kSecAttrLabel),
    kc_stringField(item, (id)kSecAttrDescription),
    kc_stringField(item, (id)kSecAttrComment),
  ];
  for (NSString *field in fields) {
    if (kc_containsKeyword(field, keyword)) {
      return YES;
    }
  }
  return NO;
}

static OSStatus kc_deleteItem(CFTypeRef kSecClassType, NSDictionary *item) {
  NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
  [query setObject:(id)kSecClassType forKey:(id)kSecClass];
  id service = [item objectForKey:(id)kSecAttrService];
  id account = [item objectForKey:(id)kSecAttrAccount];
  id server = [item objectForKey:(id)kSecAttrServer];
  id group = [item objectForKey:(id)kSecAttrAccessGroup];
  if (service) {
    [query setObject:service forKey:(id)kSecAttrService];
  }
  if (account) {
    [query setObject:account forKey:(id)kSecAttrAccount];
  }
  if (server) {
    [query setObject:server forKey:(id)kSecAttrServer];
  }
  if (group) {
    [query setObject:group forKey:(id)kSecAttrAccessGroup];
  }
  OSStatus status = SecItemDelete((CFDictionaryRef)query);
  [query release];
  return status;
}

void kc_listAccessGroups(void) {
  NSMutableDictionary *counts = [NSMutableDictionary dictionary];
  for (id secClass in kc_passwordSecClasses()) {
    NSArray *items = kc_fetchItemsForClass((CFTypeRef)secClass);
    for (NSDictionary *item in items) {
      NSString *group = kc_stringField(item, (id)kSecAttrAccessGroup);
      if (group.length == 0) {
        group = @"(unknown)";
      }
      NSNumber *n = [counts objectForKey:group];
      [counts setObject:@(n.intValue + 1) forKey:group];
    }
    [items release];
  }
  NSArray *sorted = [[counts allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
  kc_print(@"[KCleanerTS] Access groups (%lu):\n", (unsigned long)sorted.count);
  for (NSString *group in sorted) {
    if (kc_accessGroupFilter.length > 0 &&
        [group rangeOfString:kc_accessGroupFilter options:NSCaseInsensitiveSearch].location == NSNotFound) {
      continue;
    }
    kc_print(@"  %@  (%@ items)\n", group, [counts objectForKey:group]);
  }
}

static int kc_deleteItemsMatching(NSString *keyword, BOOL allPasswords) {
  int deleted = 0;
  int failed = 0;
  for (id secClass in kc_passwordSecClasses()) {
    NSArray *items = kc_fetchItemsForClass((CFTypeRef)secClass);
    for (NSDictionary *item in items) {
      if (!allPasswords && !kc_itemMatchesDeleteKeyword(item, keyword)) {
        continue;
      }
      if (allPasswords && !kc_itemPassesFilters(item)) {
        continue;
      }
      OSStatus status = kc_deleteItem((CFTypeRef)secClass, item);
      if (status == errSecSuccess || status == errSecItemNotFound) {
        deleted += 1;
      } else {
        failed += 1;
      }
    }
    [items release];
  }
  kc_print(@"[KCleanerTS] Deleted %d item(s), failures: %d\n", deleted, failed);
  return deleted;
}

int kc_deleteMatchingPasswords(NSString *keyword) {
  if (keyword.length == 0) {
    kc_print(@"[KCleanerTS] -F requires a keyword\n");
    return 0;
  }
  return kc_deleteItemsMatching(keyword, NO);
}

int kc_deleteAllPasswords(void) {
  const char *confirm = getenv("KCCLEANER_CONFIRM");
  if (!confirm || strcmp(confirm, "DELETE_ALL") != 0) {
    kc_print(@"[KCleanerTS] Refusing -X without env KCCLEANER_CONFIRM=DELETE_ALL\n");
    return 0;
  }
  return kc_deleteItemsMatching(nil, YES);
}

static NSMutableSet *kc_collectGroupsFromAPI(void) {
  NSMutableSet *groups = [NSMutableSet set];
  for (id secClass in kc_passwordSecClasses()) {
    NSArray *items = kc_fetchItemsForClass((CFTypeRef)secClass);
    for (NSDictionary *item in items) {
      NSString *group = kc_stringField(item, (id)kSecAttrAccessGroup);
      if (group.length > 0) {
        [groups addObject:group];
      }
    }
    [items release];
  }
  return groups;
}

void kc_dumpEntitlementsForTrollStore(void) {
  NSMutableSet *groups = kc_collectGroupsFromAPI();
  NSArray *sorted = [[groups allObjects] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
  NSMutableString *xml = [NSMutableString stringWithString:
    @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    @"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
    @"<plist version=\"1.0\">\n"
    @"<dict>\n"
    @"  <key>keychain-access-groups</key>\n"
    @"  <array>\n"];
  for (NSString *group in sorted) {
    [xml appendFormat:@"    <string>%@</string>\n", group];
  }
  [xml appendString:
    @"  </array>\n"
    @"  <key>platform-application</key>\n"
    @"  <true/>\n"
    @"  <key>com.apple.private.security.no-container</key>\n"
    @"  <true/>\n"
    @"  <key>com.apple.private.security.storage.Keychains</key>\n"
    @"  <true/>\n"
    @"</dict>\n"
    @"</plist>\n"];
  kc_print(@"%@", xml);
}

static NSString *kc_jsonEscape(NSString *value) {
  if (!value) {
    return @"";
  }
  NSMutableString *out = [NSMutableString stringWithCapacity:value.length];
  for (NSUInteger i = 0; i < value.length; i++) {
    unichar c = [value characterAtIndex:i];
    if (c == '\\') {
      [out appendString:@"\\\\"];
    } else if (c == '"') {
      [out appendString:@"\\\""];
    } else if (c == '\n') {
      [out appendString:@"\\n"];
    } else if (c == '\r') {
      [out appendString:@"\\r"];
    } else if (c == '\t') {
      [out appendString:@"\\t"];
    } else {
      [out appendFormat:@"%C", c];
    }
  }
  return out;
}

void kc_printPasswordItemAsJson(NSDictionary *item, CFTypeRef kSecClassType) {
  NSString *type = (kSecClassType == kSecClassGenericPassword) ? @"generic" : @"internet";
  NSString *data = kc_stringField(item, (id)kSecValueData);
  kc_print(@"{\"type\":\"%@\",\"service\":\"%@\",\"account\":\"%@\",\"server\":\"%@\",\"access_group\":\"%@\",\"label\":\"%@\",\"data\":\"%@\"}\n",
           type,
           kc_jsonEscape(kc_stringField(item, (id)kSecAttrService)),
           kc_jsonEscape(kc_stringField(item, (id)kSecAttrAccount)),
           kc_jsonEscape(kc_stringField(item, (id)kSecAttrServer)),
           kc_jsonEscape(kc_stringField(item, (id)kSecAttrAccessGroup)),
           kc_jsonEscape(kc_stringField(item, (id)kSecAttrLabel)),
           kc_jsonEscape(data));
}
