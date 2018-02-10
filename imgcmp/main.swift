//
//  main.swift
//  imgcmp
//
//  Created by Daniel Green on 07/02/2018.
//  Copyright © 2018 Daniel Green. All rights reserved.
//

import Foundation
import AppKit

func clamp01(val: Float) -> Float {
	return val < 0.0 ? 0.0 : (val > 1.0 ? 1.0 : val)
}

extension NSImage {
	func compressedJPEG(quality: Float) -> Data? {
		guard let tiff = tiffRepresentation, let bmp = NSBitmapImageRep(data: tiff) else {
			return nil
		}
		return bmp.representation(using: .jpeg, properties: [
			NSBitmapImageRep.PropertyKey.compressionFactor: clamp01(val: quality)
		])
	}
}

func handleImage(imagePath: String, quality: Float) -> Bool {
	guard let img = NSImage(contentsOfFile: imagePath) else {
		print("Failed to open image: \(imagePath)!")
		return false
	}
	
	let originalWithoutExtension = URL(fileURLWithPath: imagePath).deletingPathExtension().path
	
	// replace extension with jpg until a new non-existing file is found
	var currentIteration = 1
	var newImagePath = originalWithoutExtension + ".jpg"
	while FileManager.default.fileExists(atPath: newImagePath) {
		newImagePath = originalWithoutExtension + String(currentIteration) + ".jpg"
		currentIteration += 1
	}
	
	// write the actual image out
	return FileManager.default.createFile(atPath: newImagePath, contents: img.compressedJPEG(quality: quality), attributes: nil)
}

func isFileAllowed(pathname: String) -> Bool {
	for ext in [".jpg", ".jpeg", ".png", ".bmp"] {
		if pathname.hasSuffix(ext) {
			return true
		}
	}
	return false
}

func handleDirectory(dir: String, quality: Float) -> (Int,Int) {
	var successes = 0
	var failures = 0
	
	// enumerates recursively but includes directories and all files
	let enumerator = FileManager.default.enumerator(atPath: dir)
	
	while let element = enumerator?.nextObject() as? String {
		let fullPath = dir + "/" + element
		
		// disallow folders
		guard let type = enumerator?.fileAttributes?[FileAttributeKey.type] else {
			print("Error: Could not access attributes of \"\(fullPath)\".")
			continue
		}
		if (type as! FileAttributeType) != .typeRegular {
			continue
		}
		
		// get rid of non-file types (may false positive directories ending with dots)
		if !isFileAllowed(pathname: fullPath) {
			continue
		}
		
		// handle the image
		if handleImage(imagePath: fullPath, quality: quality) {
			successes += 1
		} else {
			failures += 1
		}
	}
	
	return (successes, failures)
}

func printUsage() {
	print("usage: imgcmp [file or folder] [quality: 0...1]")
}

func main() {
	if CommandLine.argc < 3 {
		printUsage()
		return
	}
	
	guard let quality = Float(CommandLine.arguments[2]) else {
		printUsage()
		return
	}
	
	// get command line arg for either a file or directory
	let directoryOrFile = CommandLine.arguments[1]
	
	var successes = 0
	var failures = 0
	
	var isDir: ObjCBool = false
	if FileManager.default.fileExists(atPath: directoryOrFile, isDirectory: &isDir) {
		if isDir.boolValue {
			(successes, failures) = handleDirectory(dir: directoryOrFile, quality: quality)
		} else {
			if handleImage(imagePath: directoryOrFile, quality: quality) {
				successes += 1
			} else {
				failures += 1
			}
		}
	} else {
		print("Input is not a file or directory.")
		return
	}
	
	print("Finished with \(successes) successes and \(failures) failures.")
}

main()
