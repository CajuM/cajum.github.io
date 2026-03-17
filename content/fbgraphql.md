+++
title = "Decompiling FlatBuffers case study: Facebook's GraphQL schema"
date = 2026-04-03
+++

# Background

Back in 2017, while looking for an open-source client for Facebook's Messenger, I stumbled upon fbchat. A project that implements an open-source interface for Facebook's Messenger. Knowing full-well that Facebook did not officially expose that interface for user-to-user communication, I became intrigued. From what I knew from libpurple's it would have had to use MQTT, but it was not the case. This implementation used a REST based API, digging through the source-code I found out it used a version of the GraphQL API.

After digging a bit on the internet I realised that there existed no public documentation of this particular API. Except perhaps, the occasional blog-post about a few fields or methods. And of course, what the fbchat project managed to dig-up.

Source code for the provided files and a decoded schema can be found at: fb-graphql-schema

# The first step is the hardest

But API interfaces must be known publicly, at least by the clients of those APIs. And here begins our journey. And its first task, find a client for Facebook's GraphQL API. An easy task you say? Given that we all know about the Facebook for Android and Messenger apps, even Facebook Lite, it should be easy. Unfortunately not, we do not know in what format the schema is stored, it could be compressed, obfuscated, it might exist only as byte code.

And we have one more problem, how do we find it? This problem we can answer, at least by a simple heuristic, the schema must contain the type and field names. Fortunately for us some of them have already been provided by the fbchat project. We end up with a string search through Facebook's apps. Sample GraphQL queries can be found at _graphql.py

I'm more familiar with Android so that was my platform of choice. My first try was Facebook Lite, but I had no success. Next up, Facebook for Android(aka com.facebook.katana). The version we are going to discuss is v230.0.0.36.117 , given that I revisited the schema in 2019.

In this case apktool d -r gave me a decent start. The -r flag is needed due to a bug in apktool. It disables the extraction of resources, but it won't affect the discussion.

Now, we can start looking for strings. We'll need a sufficiently uncommon string so that it doesn't match too many files, long ones are generally the best. So let's try grep -R lightweight\_event\_creator. And more sure than not, we get:

```
grep: assets/graph_metadata.bin: binary file matches
```

Given the suggestively named file, we have found our schema!


# Magic numbers

I was expecting a few months of dex reverse engineering, but the task seems to be a different one. We now have to deduce the file-type. Let's try:

```
$ file assets/graph_metadata.bin
assets/graph_metadata.bin: data
```

So it's a custom encoding, it might be ASN.1, a proprietary serialization, or anything else. This file must be read somewhere, so we might find a reference to it and hopefully to its format:

```
$ grep -R graph_metadata.bin
original/META-INF/MANIFEST.MF:Name: assets/graph_metadata.bin
original/META-INF/FACEBOOK.SF:Name: assets/graph_metadata.bin
```

Nothing useful... the code could be obfuscated or downloaded from the internet. An Android installation might provide us with more information. Let's find out where it's used:

```
$ adb root
$ adb shell

generic_arm64:/ # setenforce 0
generic_arm64:/ # stop
generic_arm64:/ # start
generic_arm64:/ # strace -ff -i -s 500 -o /data/local/tmp/strace.zygote -p $(pidof zygote)
generic_arm64:/ # grep -R graph_metadata.bin /data/local/tmp/strace.zygote.*
strace.zygote.6690:[e893a7ac] pread64(31, "assets/graph_metadata.bin", 25, 5584953) = 25
```

And in this case we got nothing, or maybe. But it's not an open, nor an openat. We have an offset let's check that with the apk:

```
$ grep -abo assets/graph_metadata.bin katana.apk
5584953:assets/graph_metadata.bin
41145638:assets/graph_metadata.bin
```

So, it's there, we now have a hint to tell gdb what condition to break on:

```
$ adb forward tcp:4444 tcp:4444
$ adb shell
generic_arm64:/ # am set-debug-app com.facebook.katana
generic_arm64:/ # setprop wrap.com.facebook.katana 'gdbserver localhost:4444'
```

Now we'll open Facebook for Android and launch gdb:

```
$ gdb
target remote :4444
break pread64
condition 1 $r4 == 5584953
```

And...

```
#0  0xf5b567a4 in pread64 () from target:/system/lib/libc.so                                                                              [36/1861]
#1  0xf6a768d8 in ?? () from target:/system/lib/libandroidfw.so
#2  0xf6a73190 in android::ZipFileRO::findEntryByName(char const*) const () from target:/system/lib/libandroidfw.so
#3  0xf6a65664 in android::AssetManager::openNonAssetInPathLocked(char const*, android::Asset::AccessMode, android::AssetManager::asset_path const&
) () from target:/system/lib/libandroidfw.so
#4  0xf6a65bd6 in android::AssetManager::open(char const*, android::Asset::AccessMode) () from target:/system/lib/libandroidfw.so
#5  0xf753c79e in AAssetManager_open () from target:/system/lib/libandroid.so
#6  0xda7f928a in ?? () from target:/data/data/com.facebook.katana/lib-xzs/libcoldstart.so
#7  0xda7f91ec in ?? () from target:/data/data/com.facebook.katana/lib-xzs/libcoldstart.so
#8  0xda7f9160 in ?? () from target:/data/data/com.facebook.katana/lib-xzs/libcoldstart.so
#9  0xda815bf0 in ?? () from target:/data/data/com.facebook.katana/lib-xzs/libcoldstart.so
#10 0xda6efece in ?? () from target:/data/data/com.facebook.katana/lib-xzs/libcoldstart.so
#11 0xda6f2186 in ?? () from target:/data/data/com.facebook.katana/lib-xzs/libcoldstart.so
#12 0xda6f2012 in ?? () from target:/data/data/com.facebook.katana/lib-xzs/libcoldstart.so
```

Looks like it's somewhere in libcoldstart.so. Let's see if we can find its format. Maybe we can get some information by looking at the libraries it links to?

```
$ adb pull /data/data/com.facebook.katana/lib-xzs/libcoldstart.so
$ readelf -a libcoldstart.so | grep 'Shared library:'
 0x00000001 (NEEDED)                     Shared library: [libz.so]
 0x00000001 (NEEDED)                     Shared library: [libdl.so]
 0x00000001 (NEEDED)                     Shared library: [liblowlevel.so]
 0x00000001 (NEEDED)                     Shared library: [libxplat_yoga_util_utilAndroid.so]
 0x00000001 (NEEDED)                     Shared library: [liblog.so]
 0x00000001 (NEEDED)                     Shared library: [libandroid.so]
 0x00000001 (NEEDED)                     Shared library: [libxplat_third-party_jsoncpp_jsoncppAndroid.so]
 0x00000001 (NEEDED)                     Shared library: [libglog.so]
 0x00000001 (NEEDED)                     Shared library: [libfmt.so]
 0x00000001 (NEEDED)                     Shared library: [libflatbuffersflatc.so]
 0x00000001 (NEEDED)                     Shared library: [libsigmux.so]
 0x00000001 (NEEDED)                     Shared library: [libfbsystrace.so]
 0x00000001 (NEEDED)                     Shared library: [libmemalign16.so]
 0x00000001 (NEEDED)                     Shared library: [libbreakpad.so]
 0x00000001 (NEEDED)                     Shared library: [libprofiloextapi.so]
 0x00000001 (NEEDED)                     Shared library: [liblinkerutilsmerged.so]
 0x00000001 (NEEDED)                     Shared library: [libdistractmerged.so]
 0x00000001 (NEEDED)                     Shared library: [libgnustl_shared.so]
 0x00000001 (NEEDED)                     Shared library: [libm.so]
 0x00000001 (NEEDED)                     Shared library: [libc.so]
```

Now we have a reference to FlatBuffers: "libflatbuffersflatc.so", could this be the format? Let's check. An easy way to see if a file is formated using FlatBuffers is to check that the first 4 bytes interpreted as an int32_t point to a table, the first int32_t in a table is the negative offset to its virtual table. Let's see:

```
$ hexdump -C graph_metadata.bin | head
00000000  20 00 00 00 00 00 00 00  00 00 16 00 28 00 04 00  | ...........(...|
00000010  08 00 0c 00 10 00 14 00  18 00 1c 00 20 00 24 00  |............ .$.|
00000020  16 00 00 00 e0 10 2f 00  10 27 25 00 04 3a 1f 00  |....../..'%..:..|
00000030  20 fd 1d 00 ac 96 13 00  94 96 13 00 68 12 13 00  | ...........h...|
00000040  b4 0e 0b 00 04 00 00 00  64 52 00 00 a0 0e 0b 00  |........dR......|
00000050  90 0e 0b 00 84 0e 0b 00  78 0e 0b 00 68 0e 0b 00  |........x...h...|
00000060  4c 0e 0b 00 28 0e 0b 00  08 0e 0b 00 e4 0d 0b 00  |L...(...........|
00000070  c8 0d 0b 00 ac 0d 0b 00  94 0d 0b 00 84 0d 0b 00  |................|
00000080  68 0d 0b 00 58 0d 0b 00  40 0d 0b 00 24 0d 0b 00  |h...X...@...$...|
00000090  08 0d 0b 00 f0 0c 0b 00  d8 0c 0b 00 c0 0c 0b 00  |................|
```

Integers in FlatBuffers are little-endian. We get: The first offset is 0x20 , it points to a 0x16 which points to the (0x16, 0x28). Assuming that 0x16 is the length of the virtual table, the data immediately after it is our root table. It would seem that it passes this heuristic.

# Decoding

To automatize the decoding process, I have written a python module:

```
https://github.com/CajuM/fb-graphql-schema/blob/master/fbs.py
```

As per the documentation, a FlatBuffers table begins with an offset to the root table. So far we know that at address 0 we have a `uint32_t` which we must de-reference to get the offset of the root table.
We introduce the following function:

```
def deref_offset(data, offset, reverse=False):
```

As previously mentioned data is our buffer, offset points to the datatype of interest in our buffer and reverse is used when we de-reference in the opposite direction.

So, to get the root table's offset we'll do:

```
root = deref_offset(data, 0)
```

A table has associated with it a piece of metadata called a vtable, the offset is stored in a `int32_t` at offset 0, relative to the table start, in our case it's root. We'll introduce the: `def get_table_vt(data, offset):` function to decode the vtable. This will return the table's length, and the number of entries in it, including optional ones. It is important to decode the vtable as a table can have optional elements and can also contain padding. The entries array is composed of offsets inside the table pointing to inline elements, together with the table length this can help our heuristic of deducing their lengths and types. In our case we'll call the function like so:

```
vt_len, tbl_len, entries = get_table_vt(data, root)
```

In this case we could get an entries vector like so:

```
entries = [4, 8, None, 12] and a tbl_len = 16
```

Take note, the offsets are always greater or equal to 4, given the vtable offset and they can be padded. We can assume that scalar types are always aligned to their size.

The simplest assumption here would be that we have three `uint32_t` fields, but this need not be the case. We can also have structs, arrays, vectors, strings or other tables. In case of the later three, we can test our hypothesis by attempting to decode the data-type, if decoding fails or we get absurd values such as offsets that exceed the buffer, non utf-8 strings, we can assume our hypothesis is false. In the case of structs, they can be identified by a length that is not the power of two, however structs can also have the same length as scalars, this ambiguity can be solved by confronting it with the alternative hypothesis, instead of a struct `A {a1: uint16_t, a2: uint16_t}` we could have an `uint32_t` or a padded u`int16_t`.

One heuristic we can apply is to check the values of each variant, if we have an `A.a2` that is always zero or an `uint32_t` that is always a multiple of `65536` we have a padded `uint16_t`. Checks on values need not be limited to the data-type stored, we can also verify them semantically, that is if in the given context a certain type and purpose would fit better. For example, we can check if an `uint16_t` is an offset inside a vector.

So far we have discussed only table ambiguities, but these also apply to vectors, A vector begins with an `int32_t` which is the element count, but this does not tell us it's element type or length. Here we may test various data types, however structs or arrays may still pose ambiguities. As such looking at a hex dump of the data may help. One can also verify that the vector does not overlap with other data structures. Strings are vectors that are null terminated and most likely contain utf-8 data.

A top-down approach can also be employed, if one knows the data-type of an element, one can test if there are any offsets to it.

So far I've got the following schema, it's incomplete, but it provides us with enough information to reconstruct all types and fields of the GraphQL API:

```
https://github.com/CajuM/fb-graphql-schema/blob/master/graph_metadata.fbs
```

To use it to decode the binary schema, we run:

```
flatc --json --strict-json --raw-binary graph_metadata.fbs -- graphql_schema.bin
```

# The final step

The schema as you've probably noticed has an extra layer of encoding, probably to reduce its size. We don't know what the types nor fields mean. The most helpful indicator is that if the type of a field is a short we can check if it's an index in a vector by checking that all values are less than the vector's length and the maximum index is close to the length of the vector.

The script I wrote to extract the types from the schema:

```
https://github.com/CajuM/fb-graphql-schema/blob/master/schema.py
```

What it basically does is that it parses each GraphQL type. The GraphQL types are stored in `ROOT.f5` with a type of `F5`. The field name is stored in `F5_f1` as a string. While the type's primary key is an optional index into `F4` named `F5.F5_f2`. Finally `F5.F5_f4` is an array of indexes into `F4`. `F4` represents all the fields in the GraphQL schema, what we know so far about it is that the field name is stored in the `F4.F4_f1` field as an index into the `F9` string table.

Finally, to get the decoded schema, we do:

```
./schema.py graphql_schema.json >graphql_types.json
```

And, we're done.

# Disclosure

I have presented my findings to Facebook, their response was that the schema is not confidential.
