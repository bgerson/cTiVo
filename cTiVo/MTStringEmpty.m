@interface MTStringEmpty : NSValueTransformer {
	
}

@end

@implementation MTStringEmpty

+ (Class)transformedValueClass { return [NSNumber class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
	
	return [NSNumber numberWithBool: ((NSString *) value).length  == 0];
}


@end

@interface MTEmptyString : NSValueTransformer {
	
}

@end

@implementation MTEmptyString //Make sure there's something (at least a space)

+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return YES; }
- (id)reverseTransformedValue:(id)value {
	
    NSString *retValue = kMTTiVoNullKey;
    if (value && (((NSString *)value).length > 0)) {
        retValue = value;
    }
    return retValue;
}
- (id)transformedValue:(id)value {
	
    NSString *retValue = @"";
    if (!value || [(NSString *)value isEqualToString:kMTTiVoNullKey]) {
        retValue = @"";
    } else {
        retValue = value;
    }
    return retValue;
}


@end

