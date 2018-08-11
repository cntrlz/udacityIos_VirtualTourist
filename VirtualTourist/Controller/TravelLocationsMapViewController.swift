//
//  TravelLocationsMapViewController.swift
//  VirtualTourist
//
//  Created by benchmark on 7/30/18.
//  Copyright © 2018 Viktor Lantos. All rights reserved.
//

import Foundation
import MapKit
import CoreData
import Alamofire

class TravelLocationsMapViewController: UIViewController {
	// IBOutlets
	@IBOutlet weak var mapView: MKMapView!
	@IBOutlet weak var editButton: UIBarButtonItem!
	
	// Local properties
	var pins: [Pin] = []
	var editingMap: Bool = false
	var trashButton: UIBarButtonItem = UIBarButtonItem()
	
	// Model properties
	var flickrClient:FlickrAPIClient!
	var dataController:DataController!
	var fetchedResultsController:NSFetchedResultsController<Pin>!
	
	// MARK: - View
	override func viewDidLoad() {
		super.viewDidLoad()
		setUpMap()
		getPins()
		configureToolbar()
		setUpFetchedResultsController()
		
		self.trashButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(trashPins))
		self.trashButton.isEnabled = false
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		navigationController?.setToolbarHidden(true, animated: false)
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		persistMapRegion()
	}
	
	func configureToolbar() {
		let hint = UIBarButtonItem(title: "Tap a pin to delete it", style: .plain, target: self, action: nil)
		hint.tintColor = UIColor.red
		let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		let items: [UIBarButtonItem] = [space, hint, space]
		self.toolbarItems = items
	}
	
	// MARK: - Navigation
	fileprivate func showAlbumForPin(_ pin: Pin?) {
		if let pin = pin {
			self.performSegue(withIdentifier: "showAlbumView2", sender: pin)
		} else {
			print("TravelLocationsMapViewController - Error - No pin provided to \(#function). This shouldn't happen.")
		}
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let vc = segue.destination as? PhotoAlbumViewController {
			vc.dataController = dataController
			vc.flickrClient = flickrClient
			vc.mapRegion = mapView.region
			if let pin = sender as? Pin {
				vc.pin = pin
			} else {
				print("TravelLocationsMapViewController - \(#function) - sender is not of Pin type. This shouldn't happen. Debug: \(sender.debugDescription)")
			}
		}
	}
	
	// MARK:  - Core Data
	fileprivate func setUpFetchedResultsController() {
		let fetchRequest:NSFetchRequest<Pin> = Pin.fetchRequest()
		let sortDescriptor = NSSortDescriptor(key: "latitude", ascending: false)
		fetchRequest.sortDescriptors = [sortDescriptor]
		
		// TODO: Figure out "couldn't read cache file to update store info timestamps" error
		// for cache name "pins"
		// For now, made cachename nil
		// Might be related to http://www.openradar.me/28361550
		fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
		fetchedResultsController.delegate = self
		
		do {
			try fetchedResultsController.performFetch()
		} catch {
			fatalError("TravelLocationsMapViewController - The fetch in \(#function) could not be performed: \(error.localizedDescription)")
		}
	}
	
	// MARK: - Map
	// TODO: - Fix collisions of pins on drop (things kinda scoot outta the way and back)
	fileprivate func setUpMap() {
		mapView.delegate = self
		
		let longPress = UILongPressGestureRecognizer(target: self, action: #selector(self.mapLongPress(_:))) // colon needs to pass through info
		longPress.minimumPressDuration = 0.5
		mapView.addGestureRecognizer(longPress)
		
		restorePersistedMapRegion()
	}
	
	func persistMapRegion() {
		let defaults = UserDefaults.standard
		let locationData = [
			"lat": mapView.centerCoordinate.latitude as Double,
			"lon": mapView.centerCoordinate.longitude as Double,
			"latd": mapView.region.span.latitudeDelta as Double,
			"lond": mapView.region.span.longitudeDelta as Double
		]
		defaults.set(locationData, forKey: "mapViewSettings")
	}
	
	func restorePersistedMapRegion() {
		let defaults = UserDefaults.standard
		if let lastSettings = defaults.dictionary(forKey: "mapViewSettings") {
			let lat = lastSettings["lat"] as! Double
			let lon = lastSettings["lon"] as! Double
			let latd = lastSettings["latd"] as! Double
			let lond = lastSettings["lond"] as! Double
			mapView.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), span: MKCoordinateSpan(latitudeDelta: latd, longitudeDelta: lond))
		}
	}
	
	fileprivate func addAnnotationForPin(_ pin: Pin){
		print("TravelLocationsMapViewController - adding pin for \(pin.latitude)-\(pin.longitude)")
		let annotation = MKPointAnnotation()
		annotation.coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
		mapView.addAnnotation(annotation)
	}
	
	fileprivate func removeAnnotationForPin(_ pin: Pin){
		for annotation in mapView.annotations {
			if annotation.coordinate.latitude == pin.latitude && annotation.coordinate.longitude == pin.longitude {
				mapView.removeAnnotation(annotation)
				if (mapView.annotations.count == 0) {
					self.trashButton.isEnabled = false
				}
			}
		}
	}
	
	// MARK: - Pins
	fileprivate func getPins() {
		let pinRequest: NSFetchRequest<Pin> = Pin.fetchRequest()
		do {
			let result = try dataController.viewContext.fetch(pinRequest)
			self.pins = result
			for pin in self.pins {
				addAnnotationForPin(pin)
			}
		} catch {
			fatalError("TravelLocationsMapViewController - The initial fetch for pins in \(#function) could not be performed: \(error.localizedDescription)")
		}
	}
	
	fileprivate func addPinForAnnotation(_ annotation: MKAnnotation) {
		let pin = Pin(context: dataController.viewContext)
		pin.latitude = annotation.coordinate.latitude
		pin.longitude = annotation.coordinate.longitude
		try? dataController.viewContext.save()
	}
	
	// MARK: - User Actions
	@objc func mapLongPress(_ recognizer: UIGestureRecognizer) {
		if self.editingMap {
			// Don't make new pins if we're editing
			return
		}
		if (recognizer.state == .began) {
			let location = recognizer.location(in: self.mapView)
			let coordinate : CLLocationCoordinate2D = mapView.convert(location, toCoordinateFrom: self.mapView)
			
			let annotation = MKPointAnnotation()
			annotation.coordinate = coordinate
			mapView.addAnnotation(annotation)
			addPinForAnnotation(annotation)
		}
	}
	
	@IBAction func edit(_ sender: Any) {
		if (self.editingMap) {
			self.editingMap = false
			editButton.title = "Edit"
			self.navigationItem.leftBarButtonItem = nil
			navigationController?.setToolbarHidden(true, animated: true)
		} else {
			self.editingMap = true
			editButton.title = "Done"
			navigationController?.setToolbarHidden(false, animated: true)
			if (mapView.annotations.count > 0) {
				self.trashButton.isEnabled = true
			}
			self.navigationItem.leftBarButtonItem = self.trashButton
		}
	}
	
	// TODO: - This process also takes a long time
	@objc func trashPins() {
		let alert = UIAlertController(title: "Delete Pins?", message: "Are you sure you want to delete all your pins, and their associated albums?", preferredStyle: UIAlertControllerStyle.alert)
		alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: nil))
		alert.addAction(UIAlertAction(title: "Delete Pins", style: UIAlertActionStyle.destructive) { action in
			// We don't have to wait for the fetched result controller's delegate methods to fire
			// It's slightly faster to clear these first, and just let the methods fire off whenever they do
			self.pins = []
			self.mapView.removeAnnotations(self.mapView.annotations)
			self.trashButton.isEnabled = false
			
			for pin in self.fetchedResultsController.fetchedObjects ?? [] {
				self.dataController.viewContext.delete(pin)
			}
			try? self.dataController.viewContext.save()
		})
		self.present(alert, animated: true, completion: nil)
	}
	
	func deletePin(_ pin: Pin?) {
		self.dataController.viewContext.delete(pin!)
		if let index = self.pins.index(of: pin!) {
			self.pins.remove(at: index)
		}
		self.removeAnnotationForPin(pin!)
	}
	
	func annotationSelected(annotation: MKAnnotation!) {
		let pin = self.pins.filter{$0.longitude == annotation.coordinate.longitude && $0.latitude == annotation.coordinate.latitude}.first
		if pin != nil {
			if self.editingMap {
				self.mapView.deselectAnnotation(annotation, animated: true)
				deletePin(pin)
			} else {
				showAlbumForPin(pin)
				self.mapView.deselectAnnotation(annotation, animated: true)
			}
		}
	}
}

// MARK: - MapView Delegate Extension
extension TravelLocationsMapViewController: MKMapViewDelegate {
	// TODO: Fix pins disappearing on map move. This is also likely related to the collisions. See: https://stackoverflow.com/questions/49020023/mapkit-annotations-disappearing
	func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
		if let annotation = view.annotation {
			self.annotationSelected(annotation: annotation)
		}
	}
	
	func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
		return nil
	}
	
	func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
		var i = -1
		for view in views {
			i += 1
			if view.annotation is MKUserLocation {
				continue
			}
			
			// Check if current annotation is inside visible map rect, else go to next one
			let point:MKMapPoint = MKMapPointForCoordinate(view.annotation!.coordinate);
			if (!MKMapRectContainsPoint(self.mapView.visibleMapRect, point)) {
				continue
			}
			
			let endFrame:CGRect = view.frame
			
			// Move annotation out of view
			view.frame = CGRect(x: view.frame.origin.x, y: view.frame.origin.y - self.view.frame.size.height, width: view.frame.size.width, height: view.frame.size.height)
			// Animate drop
			let delay = 0.03 * Double(i)
			UIView.animate(withDuration: 0.5, delay: delay, options: UIViewAnimationOptions.curveEaseIn, animations:{() in
				view.frame = endFrame
				// Animate squash
			}, completion:{(Bool) in
				UIView.animate(withDuration: 0.04, delay: 0.0, options: UIViewAnimationOptions.curveEaseOut, animations:{() in
					view.transform = CGAffineTransform.init(scaleX: 1.0, y: 0.8)
					
				}, completion: {(Bool) in
					UIView.animate(withDuration: 0.2, delay: 0.0, options: UIViewAnimationOptions.curveEaseInOut, animations:{() in
						view.transform = CGAffineTransform.identity
					}, completion: nil)
				})
				
			})
		}
	}
}

// MARK: - Fetched Result Controller Delegate Extension
extension TravelLocationsMapViewController: NSFetchedResultsControllerDelegate {
	func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
		switch type {
		case .insert:
			let pin = anObject as! Pin
			self.pins.append(pin)
			self.addAnnotationForPin(pin)
			break
		case .delete:
			let pin = anObject as! Pin
			if let index = self.pins.index(of: pin) {
				self.pins.remove(at: index)
			} else {
				print("TravelLocationsMapViewController - Attempted to delete a pin which was not in our array. This can be caused by  FetchedResultControllerDelegate methods firing multiple times.")
			}
			self.removeAnnotationForPin(pin)
			break
		case .update:
			// We don't actually care about updates. The user cannot modify a Pin's coordinates at this time
			break
		case .move:
			// Similarly, we don't need to do anything here
			break
		}
	}
}
