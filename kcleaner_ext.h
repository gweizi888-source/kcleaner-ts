#import <Foundation/Foundation.h>
#import <Security/Security.h>

typedef NS_ENUM(NSInteger, KCAction) {
  KCActionDump = 0,
  KCActionListGroups,
  KCActionDeleteKeyword,
  KCActionDeleteAllPasswords,
  KCActionDumpEntitlementsTS,
};

extern KCAction kc_action;
extern NSString *kc_filterKeyword;
extern NSString *kc_accessGroupFilter;
extern NSString *kc_deleteKeyword;
extern BOOL kc_jsonOutput;

BOOL kc_itemPassesFilters(NSDictionary *item);
void kc_listAccessGroups(void);
int kc_deleteMatchingPasswords(NSString *keyword);
int kc_deleteAllPasswords(void);
void kc_dumpEntitlementsForTrollStore(void);
void kc_printPasswordItemAsJson(NSDictionary *item, CFTypeRef kSecClassType);
