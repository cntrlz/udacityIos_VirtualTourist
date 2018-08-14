//
//  AppDelegate.swift
//  VirtualTourist
//
//  Created by benchmark on 7/30/18.
//  Copyright © 2018 Viktor Lantos. All rights reserved.
//


import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?
	let dataController = DataController(modelName: "VirtualTourist")
	let flickrClient = FlickrAPIClient()

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		dataController.load()
		
		// Configure the first view
		let navigationController = window?.rootViewController as! UINavigationController
		let travelLocationsMapViewController = navigationController.topViewController as! TravelLocationsMapViewController
		travelLocationsMapViewController.dataController = dataController
		travelLocationsMapViewController.flickrClient = flickrClient
		
		return true
	}
	
	// TODO: Better state restoration: https://developer.apple.com/documentation/uikit/view_controllers/preserving_your_app_s_ui_across_launches

	func applicationWillResignActive(_ application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
		self.saveMapRegion()
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
		self.saveMapRegion()
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		// Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}

	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
		// Saves changes in the application's managed object context before the application terminates.
		self.saveContext()
		self.saveMapRegion()
	}

	// MARK: - Core Data stack

	lazy var persistentContainer: NSPersistentContainer = {
	    /*
	     The persistent container for the application. This implementation
	     creates and returns a container, having loaded the store for the
	     application to it. This property is optional since there are legitimate
	     error conditions that could cause the creation of the store to fail.
	    */
	    let container = NSPersistentContainer(name: "VirtualTourist")
	    container.loadPersistentStores(completionHandler: { (storeDescription, error) in
	        if let error = error as NSError? {
				// TODO: Replace this implementation with appropriatel error handling. Hasn't crashed this way... yet...
	            print("Unresolved error in AppDelegate in \(#function) \(error)")
				
				// Some copied-over tips:
				/*
				Typical reasons for an error here include:
				* The parent directory does not exist, cannot be created, or disallows writing.
				* The persistent store is not accessible, due to permissions or data protection when the device is locked.
				* The device is out of space.
				* The store could not be migrated to the current model version.
				Check the error message to determine what the actual problem was.
				*/
	        }
	    })
	    return container
	}()

	// MARK: - Core Data Saving support
	func saveContext () {
	    let context = persistentContainer.viewContext
	    if context.hasChanges {
	        do {
	            try context.save()
	        } catch {
				// TODO: Like above, replace this with code to handle the error appropriately.
	            let nserror = error as NSError
				print("Unresolved error in AppDelegate in \(#function) \(nserror), \(nserror.userInfo)")
	        }
	    }
	}
	
	func saveMapRegion () {
		let navigationController = window?.rootViewController as! UINavigationController
		if let travelLocationsMapViewController = navigationController.topViewController as? TravelLocationsMapViewController {
			travelLocationsMapViewController.persistMapRegion()
		}
	}

}

