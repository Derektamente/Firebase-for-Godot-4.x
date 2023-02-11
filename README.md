<p align="center"><img src="https://brandslogos.com/wp-content/uploads/thumbs/firebase-logo-vector.svg" width="80px"/></p>

# Firebase API for Godot 4.x

Adds Firebase compatibility to your Godot 4.x project.

<br>

## Install

Make sure there's no other `Firebase` plugin/autoload in your project.

1. Get the addon. You can either:
- use the built-in AssetLib to search and install `Firebase API (4.x)`
- download the ZIP file from GitHub and put the `addons` folder in your project's main directory
2. Enable the plugin in `Project > Project Settings > Plugins`

If it's enabled but you still have no `Firebase` in your autoloads, disable and re-enable it again.

<br>

---
<br>


## Use

Unlike [GodotFirebase](https://github.com/GodotNuts/GodotFirebase), on which this library is based, you initialize it manually.

Add this to your `main scene` and enter your [Firebase configuration](https://support.google.com/firebase/answer/7015592?hl=en#zippy=%2Cin-this-article) as fields of the corresponding keys in `firebaseConfig`:

```
const firebaseConfig = {
	"apiKey": "",
	"authDomain": "",
	"databaseURL": "",
	"projectId": "",
	"storageBucket": "",
	"messagingSenderId": "",
	"appId": "",
	"measurementId": ""
}

func _ready():
    Firebase.setup_modules(firebaseConfig)
```

This approach allows you to have multiple Firebase configurations in the same application and apply them at runtime. Like this:
```
const configs = {
    "config1" : {...},
    "config2" : {...}
}

func _ready():
    Firebase.setup_modules(configs.config1)
    do_some_things()
    Firebase.setup_modules(configs.config2)
    do_other_things()
```

<br>

---
<br>

## Differences with GodotFirebase
Despite a slightly different architecture, Firebase API 4.x inherited most of the original methods and signals, so you can refer to the original [wiki](https://github.com/GodotNuts/GodotFirebase/wiki) for guidance.

The only differences in nomenclature are as follows:

<br>

`FirestoreCollection` class:

|GodotFirebase|Firebase API 4.x|
|-|-|
|`func get(...)` *|`func get_doc(...)`|

<sup>* get() is reserved in Godot 4

<br>

`FirestoreCollection` and `FirestoreTask` classes:

|GodotFirebase|Firebase API 4.x|
|-|-|
|`signal add_document(doc)`|`signal document_added(doc)`|
|`signal get_document(doc)`|`signal document_got(doc)`|
|`signal update_document(doc)`|`signal document_updated(doc)`|
|`signal delete_document`|`signal document_deleted`|

<br>

`Firestore` and `FirestoreTask` classes:
|GodotFirebase|Firebase API 4.x|
|-|-|
|`signal listed_documents(docs)`|`signal documents_listed(docs)`|

<br>

## Firebase Realtime Database

Besides initialization, the only significant usage-wise difference with GodotFirebase involves Firebase Realtime Database.

To initialize a Realtime Database reference, use this method of `FirebaseRealtime`:
```
func get_realtime_reference(path := "", filter := {}) -> FirebaseRealtimeReference
```

Providing a path is optional: if you don't, the reference will work through the entire database, but will only listen to the initial key map (e.g. if new keys are added to the database after referencing, it won't detect them or their changes).

<br>

The following will allow you to listen for changes in the database (or the given path):
```
func _ready():
    var path : String
    var ref = Firebase.Realtime.get_realtime_reference(path)
    ref.new_data_update.connect(myfunc)

func myfunc(update):
    print(update.data)
```

The signal `new_data_update` is emitted everytime there's a change in the referenced path in your database.

<br>

A path is optional when calling `FirebaseRealtimeReference.update()` too. The method will just use the reference's path, if possible.



Examples:

```
func _ready():
    var ref = Firebase.Realtime.get_realtime_reference()
    var somedata = {...}
    ref.update(somedata, "path")
```
This will update `root/path`.

<br>

```
func _ready():
    var ref = Firebase.Realtime.get_realtime_reference("path")
    var somedata = {...}
    ref.update(somedata)
```
This will update `root/path` too.

<br>

```
func _ready():
    var ref = Firebase.Realtime.get_realtime_reference("path")
    var somedata = {...}
    ref.update(somedata, "more_path")
```
This will update `root/path/more_path`.

<br>

Trying to `update()` the database root with a non-Dictionary value will result in a soft error:
```
func _ready():
    # don't do this
    var ref = Firebase.Realtime.get_realtime_reference() # no initial path is provided
    ref.update("asdasd") # no additional path is provided and data is not a Dictionary
    
    # will print an error
```
<br>

Be aware that calling `delete()` in a reference with no initial path will result in the complete deletion of the database's content.
