+++
date = 2020-12-30
title = "Decompiling FlatBuffers case study: Facebook's GraphQL schema"
+++

Background
==========

Back in 2017, while looking for an open-source client for Facebook's Messenger,
I stumbled upon [fbchat](https://fbchat.readthedocs.io/en/stable/).
A project that implements an open-source interface for Facebook's Messenger.
Knowing full-well that Facebook did not officially expose that interface for user-to-user communication, I became intrigued.
From what I knew from [libpurple's](https://github.com/dequis/purple-facebook) it would have had to use MQTT, but it was not the case.
This implementation used a REST based API, digging through the source-code I found out it used a version of the GraphQL API.

After digging a bit on the internet I realised that there existed no public documentation of this particular API.
Except perhaps, the occasional blog-post about a few fields or methods. And of course, what the fbchat project
managed to dig-up.

Source code for the provided files and a decoded schema can be found at: [fb-graphql-schema](https://github.com/CajuM/fb-graphql-schema)

The first step is the hardest
=============================

But API interfaces must be known publicly, at least by the clients of those APIs.
And here begins our journey. And its first task, find a client for Facebook's GraphQL API.
An easy task you say? Given that we all know about the Facebook for Android and Messenger apps, even Facebook Lite, it should be easy.
Unfortunately not, we do not know in what format the schema is stored, it could be compressed, obfuscated, it might exist only as byte code.

And we have one more problem, how do we find it?
This problem we can answer, at least by a simple heuristic, the schema must contain the type and field names.
Fortunately for us some of them have already been provided by the fbchat project.
We end up with a string search through Facebook's apps.
Sample GraphQL queries can be found at [\_graphql.py](https://github.com/fbchat-dev/fbchat/blob/master/fbchat/_graphql.py)

I'm more familiar with Android so that was my platform of choice.
My first try was Facebook Lite, but I had no success.
Next up, Facebook for Android(aka com.facebook.katana).
The version we are going to discuss is v230.0.0.36.117 , given that I revisited the schema in 2019.

In this case `apktool d -r` gave me a decent start. The `-r` flag is needed due to a bug in apktool.
It disables the extraction of resources, but it won't affect the discussion.

Now, we can start looking for strings.
We'll need a sufficiently uncommon string so that it doesn't match too many files, long ones are generally the best.
So let's try `grep -R lightweight_event_creator`. And more sure than not, we get:
```
grep: assets/graph_metadata.bin: binary file matches
```
Given the suggestively named file, we have found our schema!

Magic numbers
=============

I was expecting a few months of dex reverse engineering, but the task seems to be a different one.
We now have to deduce the file-type. Let's try:
```
$ file assets/graph_metadata.bin
assets/graph_metadata.bin: data
```
So it's a custom encoding, it might be ASN.1, a proprietary serialization, or anything else.
This file must be read somewhere, so we might find a reference to it and hopefully to its format:
```
$ grep -R graph_metadata.bin
original/META-INF/MANIFEST.MF:Name: assets/graph_metadata.bin
original/META-INF/FACEBOOK.SF:Name: assets/graph_metadata.bin
```
Nothing useful... the code could be obfuscated or downloaded from the internet.
An Android installation might provide us with more information.
Let's find out where it's used:
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
And in this case we got nothing, or maybe. But it's not an open, nor an openat.
We have an offset let's check that with the apk:
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
Looks like it's somewhere in libcoldstart.so. Let's see if we can find its format.
Maybe we can get some information by looking at the libraries it links to?
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
Now we have a reference to FlatBuffers: "libflatbuffersflatc.so", could this be the format?
Let's check. An easy way to see if a file is formated using FlatBuffers is to check that the
first 4 bytes interpreted as an int32_t point to a table, the first int32_t in a table is the
negative offset to its virtual table. Let's see:
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
Integers in FlatBuffers are little-endian. We get:
The first offset is 0x20 , it points to a 0x16 which points to the (0x16, 0x28).
Assuming that 0x16 is the length of the virtual table, the data immediately after it is
our root table. It would seem that it passes this heuristic.

Decoding
========

To automatize the decoding process, I have written a python module:
```
$ echo 'H4sIAAAAAAACA51UTY+bQAy98yt8qQY26TZK94TC3rZSLz31UCmKEAmmGZUM0TCgbVf57/UwDgwhiVbLJQQ/P9vPH/JwrLSB2uhmZ4IgyLGAHHdVjmlr0syEeWayOVRFUaOJ4gDoIUOJChL4jSat9+Q/RnUgsy3vomAGyyjooLKAkDlXsIig0hCe3e0HF9U+OpM1wsvrDo9GVioU31WblTKHVmrTZCWYbFuimPJ+omAfpSEKpVEZKkUqc2b8YtPnKD1iBV8/GoXctcSagrhePDbqmO3+hGIlSCqxF/DQx5mDVXLthIwHQV1qm2i9jDeOVaNptIK3PinhMCJm8HywsORk4jfPxtmRjd8606kfGI1F6tIYNXlOCbSoa0y+ZWWN3AKy8VhYPcejc5aU/Tw1XSVc62f70tmceOVt6KyDukRtzE51Gu4bk81eyb2ifuoGI1/fKxvTU0Ve7Em9sc9y2XgpbjX6iXq82HjEV7bwLvX+JvXykrrFnal0iuWFCFim5u8R56DO4jngsPTT7nqwbUbLkXgl9a1X8Jx4ZO9YKCahu+HcvANgUww51QhkbVd4YCRDLf/ZPBgSXBmnAWQR9Zr/jzfMr2pGJTyc3SaTV0gs8wstewkNS3d9SF1yqduf1qz7tdys1aYvmQEJLCYr8aNSOEq7l79z4lz3+JrmzeEYbptiGCMKKYRzLkhpJCWBAKMYMCMQvMWL5a+TeCTYgfYBo1FI+qE4nZRE6S6ToK7QbfHOlNso+saD5N0iqyoZntwJcgbRLcAdis4+JVnyHTsF/wFyfW7uCQcAAA==' | base64 -d | gunzip >fbs.py
```

Running:
```
>>> import fbs
>>> data = open('graph_schema.bin', 'rb').read()
>>> root = root = fbs.deref_offset(data, 00)
>>> fbs.get_table_vt(data, root)
{'vt_len': 22, 'tbl_len': 40, 'entries': (4, 8, 12, 16, 20, 24, 28, 32, 36)}
```
From here it's a lot of guess work, and trial and error.
So far I've got the following schema, it's incomplete, but it provides us with enough
information to reconstruct all types and fields of the GraphQL API:
```
echo 'H4sIAAAAAAACA5WWzW6jMBDH7zzFPEClNtgGkhxy41pptbcoipxiGlQKFTjbRdW++9oeoG4C2LngyPnNf8bMh5H8VApIV/AVgFqO+WqzV0u6OmwB4PERZJ3VG/g8cwl53eyCf0HQyubyIsFggx2atue6kdtJu5EKlyilLjGiEJVDLXspKs0DzCmHWnavMRO2I26C0sSOeFaa2BEvUcSLol4U86IiB2UdmeKR6e2RiyoTf9UT0vUD5IUoM6j4u+jpcJZmPUFmichOJ8MAmAlANkX1Oiaq+xCjS3br8qMp3nnTwZvodj1CNnvDDDX67ZP2Z2h7kl6R8/UWY4DxRIC3Lz/2KorYRKqWlMz5R4p6aTHUYstakZdW7EUlkz2Fe1C0wMtP3rWwDwk9PEAhzV6lEvGHl0UGdZ63QqqdDLSJZZH0Dtbu1tYJebIwRfUi/NSKStopPA6trX9dlfqSB2xyzNQxDX1mSI9a7nBU2R4X3OHEcsA/3bHRF3OPWqQ8R22CyonXqE207KWs+/6Yp4gXRSc9qkqRZ/VoBC874KZ8Bgt2t0V0t0V8t4VqFbWkyUJzJnP1vqTrrP2hQrTzIY+YSiv3V3FgEif/H6vi1/Pzb6OHXwQHRxeZ/gmdlJ6HxEmpqZ1SJ6XnIXNSkX0DIHXirTDXTruzrz9Nx3oKODVNsp3UWnk2F8lh6YZu6loezR2o3/g2+A9/wCAZkQkAAA==' | base64 -d | gunzip >graph_metadata.fbs
```

The final step
==============

The schema as you've probably noticed has an extra layer of encoding, probably to reduce its size.
We don't know what the types nor fields mean. The most helpful indicator is that if the type of a field
is a short we can check if it's an index in a vector by checking that all values are less than the vector's
length and the maximum index is close to the length of the vector.

We'll skip over the manual decoding. I'll just show you the script I wrote to extract the types from the schema:
```
echo 'H4sIAAAAAAACA5VUwW7CMAy95ysy7ZAiVWUUmLRJXHfcD1RR1NEUytqkSgJShfbvc+KWFhiH9RTe87Of7YTnp/nRmvlXpeZSnWjbub1WS0KqptXG0YPVajjbzhJCClnSrVYnaZwoK1kX0aGI6S4cZ++EwqfyRtINPRQZK98Yz5DM2MdKlAvGOQlRZQoxUyplHInlDbFkvaQqPVkpmr3EdMGxmv92rmsvJddQskw5aNehXoiS9ShexXQd09dH+jfU35ZcgOoPCcvOP5wlpTZN7qKAzlBqpDsaRc8XCfODYe9hPvGIegmgQYrwz82cPYNjDumvphygsdfBdABS5p2HiNF4a6omN534lt3Q8covacyT+h39HX6/+Qnf9y1r+7Dcp1ayX7/PYAHK+q1rg9jFMpqB5Y/JMGDiOgD8jr+3iffzOtAmedtKVUQ9+a+tTfoCcvJrEoNVgMbD9XKbvFJQWfXrhBMY1+DHgzFlxjH0ewgdw0NMap0XQYJW7XYvm/x6hHgtIdfwFO5v7INbdYnDtMNspjc6mCiOTRthTOz/ExLrCn10s2GtKtnW2soIAAIXUQg/OCHoBt6KEL5rIRi6CiPwKXKzO2ULPiO/Stbkt48EAAA=' | base64 -d | gunzip >schema.py
```

```
flatc --json --strict-json --raw-binary graph_metadata.fbs -- graphql_schema.bin
./schema.py graphql_schema.json >graphql_types.json
```

And, we're done.

Disclosure
==========

I have presented my findings to Facebook, their response was that the schema is not confidential.
