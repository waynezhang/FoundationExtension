//
//  NSDataAdditions.m
//  FoundationExtension
//
//  Created by youknowone on 10. 10. 17..
//  Copyright 2010 youknowone.org All rights reserved.
//

#import "NSURLAdditions.h"
#import "NSURLRequestAdditions.h"
#import "NSDataAdditions.h"

#include "debug.h"

@implementation NSData (FoundationExtensionCreation)

- (id)initWithContentsOfURL:(NSURL *)url postBody:(NSDictionary *)bodyDictionary encoding:(NSStringEncoding)encoding {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPPostBody:bodyDictionary encoding:encoding];
    id result = [self initWithData:[NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:NULL]];
    [request release];
    return result;
}

+ (NSData *)dataWithContentsOfURL:(NSURL *)url postBody:(NSDictionary *)bodyDictionary encoding:(NSStringEncoding)encoding {
    return [[[self alloc] initWithContentsOfURL:url postBody:bodyDictionary encoding:encoding] autorelease];
}

- (id)initWithContentsOfURLRequest:(NSURLRequest *)request {
    return [self initWithData:[NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:NULL]];
}

+ (NSData *)dataWithContentsOfURLRequest:(NSURLRequest *)request {
    return [[[self alloc] initWithContentsOfURLRequest:request] autorelease];
}

- (id)initWithContentsOfURLRequest:(NSURLRequest *)request error:(NSError **)error {
    return [self initWithData:[NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:error]];
}

+ (NSData *)dataWithContentsOfURLRequest:(NSURLRequest *)request error:(NSError **)error {
    return [[[self alloc] initWithContentsOfURLRequest:request error:error] autorelease];
}

- (id)initWithContentsOfAbstractPath:(NSString *)path {
    return [self initWithContentsOfURL:[NSURL URLWithAbstractPath:path]];
}

+ (NSData *)dataWithContentsOfAbstractPath:(NSString *)path {
    return [[[self alloc] initWithContentsOfURL:[NSURL URLWithAbstractPath:path]] autorelease];
}

- (id)initWithContentsOfAbstractPath:(NSString *)path options:(NSDataReadingOptions)opt error:(NSError **)error {
    return [self initWithContentsOfURL:[NSURL URLWithAbstractPath:path] options:opt error:error];
}

+ (NSData *)dataWithContentsOfAbstractPath:(NSString *)path options:(NSDataReadingOptions)opt error:(NSError **)error {
    return [[[self alloc] initWithContentsOfURL:[NSURL URLWithAbstractPath:path] options:opt error:error] autorelease];
}

@end


@implementation NSData (FoundationExtensionSerialization)

const char NSDataAdditionsHexadecimalEncodingTable[16] = "0123456789abcdef";

- (NSString *)hexadecimalString {
    NSUInteger length = self.length;
    unsigned char *inpos = (unsigned char *)self.bytes;
    const unsigned char *inendian = self.bytes + length;
    
    char *buffer = malloc(length * 2);
    char *outpos = buffer;
    
    for ( ; inpos < inendian; inpos += 1, outpos += 2) {
        *(outpos + 0) = NSDataAdditionsHexadecimalEncodingTable[*inpos >> 4];
        *(outpos + 1) = NSDataAdditionsHexadecimalEncodingTable[*inpos & 0x0f];
    }
    return [[[NSString alloc] initWithBytesNoCopy:buffer length:length * 2 encoding:NSUTF8StringEncoding freeWhenDone:YES] autorelease];
}

static const char NSDataAdditionsHexadecimalDecodingTable[0x80] =
//0           4           8          12          16
{-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,// 16
 -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,// 32
 -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,// 48
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9,-1,-1,-1,-1,-1,-1,// 64
 -1,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,-1,// 80
 -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,// 96
 -1,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,-1,//112
 -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,//128
};

- (id)initWithHexadecimalString:(NSString *)hexadecimal {
    NSData *hexData = [hexadecimal dataUsingEncoding:NSASCIIStringEncoding];
    const unsigned char *bytes = hexData.bytes;
    NSUInteger length = hexData.length;
    const unsigned char *endian = bytes + length;
    
    char *buffer = (char *)malloc(length / 2);
    char *pointer = buffer;

    for (unsigned char *pos = (unsigned char *)bytes; pos < endian; pos += 2, pointer += 1) {
        *pointer = (NSDataAdditionsHexadecimalDecodingTable[*pos] << 4) + NSDataAdditionsHexadecimalDecodingTable[*(pos+1)];
    }

    return [[NSData alloc] initWithBytesNoCopy:buffer length:length / 2 freeWhenDone:YES];
}

+ (NSData *)dataWithHexadecimalString:(NSString *)hexadecimal {
    return [[[self alloc] initWithHexadecimalString:hexadecimal] autorelease];
}


char NSDataAdditionsBase64EncodingTable[64] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static void NSDataAdditionsBase64EncodeData(const unsigned char *input, char *output) {
    output[0] = NSDataAdditionsBase64EncodingTable[((input[0] & 0xfc) >> 2)];
    output[1] = NSDataAdditionsBase64EncodingTable[((input[0] & 0x03) << 4) | ((input[1] & 0xf0) >> 4)];
    output[2] = NSDataAdditionsBase64EncodingTable[((input[1] & 0x0f) << 2) | ((input[2] & 0xc0) >> 6)];
    output[3] = NSDataAdditionsBase64EncodingTable[((input[2] & 0x3f)     )];
}

- (NSString *)base64String {
    NSUInteger inlen = self.length;
    if (inlen == 0) {
        return @"";
    }
    NSUInteger roughlen = (inlen * 4) / 3;
    NSUInteger outlen = 4 * ((roughlen / 4) + ((roughlen % 4) != 0));
    char *outbuf = malloc(outlen + 1);
    outbuf[outlen] = 0;
    
    unsigned char *inpos = (unsigned char *)self.bytes;
    const unsigned char *inendian = inpos + inlen;
    
    char *outpos = outbuf;
    
    while (inendian - inpos >= 3) {
        NSDataAdditionsBase64EncodeData(inpos, outpos);
        inpos += 3;
        outpos += 4;
    }
    
    NSInteger taillen = inendian - inpos;
    dassert(taillen >= 0);
    if (taillen) {
        unsigned char tailbuf[3];
        tailbuf[0] = inpos[0];
        tailbuf[1] = taillen == 2 ? inpos[1] : 0;
        tailbuf[2] = 0;
        NSDataAdditionsBase64EncodeData(tailbuf, outpos);
        if (taillen != 2) {
            outpos[2] = '=';
        }
        outpos[3] = '=';
        dassert(outpos + 4 == outbuf + outlen);
    }
    
    return [[[NSString alloc] initWithBytesNoCopy:outbuf length:outlen encoding:NSUTF8StringEncoding freeWhenDone:YES] autorelease];
}

unsigned char NSDataAdditionsBase64DecodingTable[0x80] = {
//   0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, // 0x10
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, // 0x20
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 62, -1, -1, -1, 63, // 0x30
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -1, -1, -1, -1, -1, -1, // 0x40
    -1,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, // 0x50
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -1, -1, -1, -1, -1, // 0x60
    -1, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, // 0x70
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -1, -1, -1, -1, -1, // 0x80
};

static void NSDataAdditionsBase64DecodeData(const char *input, unsigned char *output) {
    unsigned char tmp1 = NSDataAdditionsBase64DecodingTable[input[0]];
    dassert(tmp1 != 0xff);
    unsigned char tmp2 = NSDataAdditionsBase64DecodingTable[input[1]];
    dassert(tmp2 != 0xff);
    output[0] = (tmp1 << 2) | (tmp2 >> 4);
    tmp1 = NSDataAdditionsBase64DecodingTable[input[2]];
    dassert(tmp1 != 0xff);
    output[1] = (tmp2 << 4) | (tmp1 >> 2);
    tmp2 = NSDataAdditionsBase64DecodingTable[input[3]];
    dassert(tmp2 != 0xff);
    output[2] = (tmp1 << 6) | (tmp2);
}

- (id)initWithBase64String:(NSString *)base64 {
    NSUInteger inlen = base64.length;
    NSUInteger datalen = inlen / 4 * 3;
    char *inpos = (char *)base64.UTF8String;
    NSUInteger remain = inlen % 4;
    switch (remain) {
        case 0:
            if (inpos[inlen-2] == '=') {
                inlen -= 2;
                datalen -= 2;
            } else if (inpos[inlen-1] == '=') {
                inlen -= 1;
                datalen -= 1;
            }
            break;
        case 2:
            datalen += 1;
            break;
        case 3:
            datalen += 2;
            break;
        default:
            dassert(0);
    }
    
    const char *inendian = inpos + inlen;
    
    unsigned char *buffer = malloc(datalen);
    unsigned char *outpos = buffer;
    
    while (inendian - inpos >= 4) {
        NSDataAdditionsBase64DecodeData(inpos, outpos);
        inpos += 4;
        outpos += 3;
    }
    
    NSInteger taillen = inendian - inpos;
    dassert(taillen > 0);
    if (taillen) {
        unsigned char tmp1 = NSDataAdditionsBase64DecodingTable[inpos[0]];
        unsigned char tmp2 = NSDataAdditionsBase64DecodingTable[inpos[1]];
        outpos[0] = (tmp1 << 2) + (tmp2 >> 4);
        if (taillen == 3) {
            tmp1 = NSDataAdditionsBase64DecodingTable[inpos[2]];
            outpos[1] = (tmp2 << 4) + (tmp1 >> 2);
        }
    }
    
    return [self initWithBytesNoCopy:buffer length:datalen freeWhenDone:YES];
}

+ (id)dataWithBase64String:(NSString *)base64 {
    return [[[self alloc] initWithBase64String:base64] autorelease];
}

@end
