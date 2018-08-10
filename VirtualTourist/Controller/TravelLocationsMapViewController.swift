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
	@IBOutlet weak var mapView: MKMapView!
	@IBOutlet weak var editButton: UIBarButtonItem!
	
	var pins: [Pin] = []
	var editingMap: Bool = false
	var trashButton: UIBarButtonItem = UIBarButtonItem()
	
	var flickrClient:FlickrAPIClient!
	var dataController:DataController!
	var fetchedResultsController:NSFetchedResultsController<Pin>!
	
	// MARK: - View
	override func viewDidLoad() {
		super.viewDidLoad()
		setUpMap()
		getPins()
		setupFetchedResultsController()
		
		self.trashButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(trashPins))
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		navigationController?.setToolbarHidden(true, animated: false)
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		persistMapRegion()
	}
	
	// MARK: - Navigation
	fileprivate func showAlbumForPin(_ pin: Pin?) {
		if let pin = pin {
			self.performSegue(withIdentifier: "showAlbumView", sender: pin)
		} else {
			print("Error - No pin in showAlbumForPin")
		}
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let vc = segue.destination as? PhotoAlbumViewController {
			vc.dataController = dataController
			vc.flickrClient = flickrClient
			if let pin = sender as? Pin {
				vc.pin = pin
			} else {
				print("Prepare for segue - sender is not pin: \(sender.debugDescription)")
			}
		}
	}
	
	// MARK: Core Data
	fileprivate func setupFetchedResultsController() {
		let fetchRequest:NSFetchRequest<Pin> = Pin.fetchRequest()
		// TODO: Why latitude gee
		let sortDescriptor = NSSortDescriptor(key: "latitude", ascending: false)
		fetchRequest.sortDescriptors = [sortDescriptor]
		
		fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: "pins")
		fetchedResultsController.delegate = self
		
		do {
			try fetchedResultsController.performFetch()
		} catch {
			fatalError("The fetch could not be performed: \(error.localizedDescription)")
		}
	}
	
	// MARK: - Map
	fileprivate func setUpMap() {
		mapView.delegate = self
		
		let longPress = UILongPressGestureRecognizer(target: self, action: #selector(self.mapLongPress(_:))) // colon needs to pass through info
		longPress.minimumPressDuration = 1.0
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
			}
		}
	}
	
	@objc func mapLongPress(_ recognizer: UIGestureRecognizer) {
		if (recognizer.state == .began) {
			let location = recognizer.location(in: self.mapView)
			let coordinate : CLLocationCoordinate2D = mapView.convert(location, toCoordinateFrom: self.mapView)
			
			let annotation = MKPointAnnotation()
			annotation.coordinate = coordinate
			mapView.addAnnotation(annotation)
			addPinForAnnotation(annotation)
		}
	}
	
	@IBAction func editButtonTapped(_ sender: Any) {
		if (self.editingMap) {
			self.editingMap = false
			editButton.title = "Edit"
			self.navigationItem.leftBarButtonItem = nil
		} else {
			self.editingMap = true
			editButton.title = "Done"
			self.navigationItem.leftBarButtonItem = self.trashButton
		}
	}
	
	// TODO: If no pins to delete, disable button
	@objc func trashPins() {
		let alert = UIAlertController(title: "Delete Pins?", message: "Are you sure you want to delete all your pins, and their associated albums?", preferredStyle: UIAlertControllerStyle.alert)
		alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: nil))
		alert.addAction(UIAlertAction(title: "Delete Pins", style: UIAlertActionStyle.destructive) { action in
			// We don't have to wait for the fetched result controller's delegate methods to fire
			// It's slightly faster to clear these first, and just let the methods fire off
			self.pins = []
			self.mapView.removeAnnotations(self.mapView.annotations)
			
			for pin in self.fetchedResultsController.fetchedObjects ?? [] {
				self.dataController.viewContext.delete(pin)
			}
			try? self.dataController.viewContext.save()
		})
		self.present(alert, animated: true, completion: nil)
	}
	
	func annotationSelected(annotation: MKAnnotation!) {
		let pin = self.pins.filter{$0.longitude == annotation.coordinate.longitude && $0.latitude == annotation.coordinate.latitude}.first
		if pin != nil {
			if self.editingMap {
				self.mapView.deselectAnnotation(annotation, animated: true)
				self.dataController.viewContext.delete(pin!)
				if let index = self.pins.index(of: pin!) {
					self.pins.remove(at: index)
				}
				self.removeAnnotationForPin(pin!)
			} else {
				showAlbumForPin(pin)
				self.mapView.deselectAnnotation(annotation, animated: true)
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
			fatalError("The fetch could not be performed: \(error.localizedDescription)")
		}
	}
	
	fileprivate func addPinForAnnotation(_ annotation: MKAnnotation) {
		let pin = Pin(context: dataController.viewContext)
		pin.latitude = annotation.coordinate.latitude
		pin.longitude = annotation.coordinate.longitude
		try? dataController.viewContext.save()
	}
}

// MARK: - MapView Delegate Extension
extension TravelLocationsMapViewController: MKMapViewDelegate {
	// TODO: Allow tapping an already-selected annotation
	// TODO: Fix pins disappearing on map move. See: https://stackoverflow.com/questions/49020023/mapkit-annotations-disappearing
	func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
		if let annotation = view.annotation {
			self.annotationSelected(annotation: annotation)
		}
	}
}

// MARK: - MapView Delegate Extension
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
				print("Attempted to delete a pin which was not in our array")
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
