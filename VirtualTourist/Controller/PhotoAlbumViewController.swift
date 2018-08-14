//
//  TravelLocationsMapViewController.swift
//  VirtualTourist
//
//  Created by benchmark on 7/30/18.
//  Copyright © 2018 Viktor Lantos. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import MapKit

class PhotoAlbumViewController: UIViewController, UIGestureRecognizerDelegate {
	// IBOutlets
	@IBOutlet weak var collectionView: UICollectionView!
	@IBOutlet weak var mapView: MKMapView!
	
	// UI Elements
	var newCollectionButton: UIBarButtonItem = UIBarButtonItem()
	var deleteAlbumButton: UIBarButtonItem = UIBarButtonItem()
	var activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView()
	
	// Model
	var flickrClient:FlickrAPIClient!
	var dataController: DataController!
	var fetchedResultsController:NSFetchedResultsController<Photo>!
	
	// Local properties
	var pin: Pin!
	var mapRegion: MKCoordinateRegion = MKCoordinateRegion()
	var blockOperations: [BlockOperation] = []
	var selectedIndexPaths: [IndexPath] = []

	// MARK: - View
	override func viewDidLoad() {
		configureView()
		configureMapView()
		configureCollectionView()
		setupFetchedResultsController()
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		Onboarding.photoAlbum()
		if (fetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0) {
			self.newCollectionButton.isEnabled = true
			self.newCollectionButton.title = "New Collection"
		} else {
			self.activityIndicator.startAnimating()
		}
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		fetchedResultsController = nil
	}
	
	func configureView() {
		configureToolbarItems()
		configureActivityIndicator()
		
		deleteAlbumButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deletePressed))
		deleteAlbumButton.isEnabled = false
		navigationItem.rightBarButtonItem = deleteAlbumButton
	}

	func configureToolbarItems() {
		toolbarItems = makeToolbarItems()
		navigationController?.setToolbarHidden(false, animated: false)
	}
	
	func configureActivityIndicator() {
		let indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.whiteLarge)
		indicator.color = UIColor.gray
		indicator.center = view.center
		indicator.hidesWhenStopped = true
		self.activityIndicator = indicator
		view.addSubview(indicator)
	}
	
	func makeToolbarItems() -> [UIBarButtonItem] {
		let newCollection = UIBarButtonItem(title: "New Collection", style: .plain, target: self, action: #selector(newCollection(sender:)))
		newCollection.isEnabled = false
		self.newCollectionButton.title = "Fetching Photos..."
		self.newCollectionButton = newCollection
		let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		return [space, newCollection, space]
	}
	
	// Make things prettier
	// TODO: Funny layout on small screen widths
	fileprivate func configureCollectionView() {
		// Flow
		let flow = UICollectionViewFlowLayout()
		let itemSpacing: CGFloat = 2
		let collectionViewWidth = collectionView!.bounds.size.width
		let minimumCellWidth: CGFloat = 120

		let cellsPerRowMinusSpacing = CGFloat(Int(collectionViewWidth / minimumCellWidth) - 1)
		let widthMinusAllSpacing = collectionViewWidth - cellsPerRowMinusSpacing * itemSpacing
		let itemsPerRow = CGFloat(Int(widthMinusAllSpacing / minimumCellWidth))
		let width = collectionViewWidth - itemSpacing * (itemsPerRow - 1)
		let cellWidth = floor(width / itemsPerRow)
		let realItemSpacing = itemSpacing + (width / itemsPerRow - cellWidth) * itemsPerRow / (itemsPerRow - 1)

		let edgeSpacing : CGFloat = 4
		flow.sectionInset = UIEdgeInsets(top: edgeSpacing, left: edgeSpacing, bottom: edgeSpacing, right: edgeSpacing)
		flow.itemSize = CGSize(width: cellWidth - edgeSpacing, height: cellWidth - edgeSpacing)
		flow.minimumInteritemSpacing = realItemSpacing
		flow.minimumLineSpacing = realItemSpacing
		
		// User interaction
		collectionView?.setCollectionViewLayout(flow, animated: false)
		collectionView.allowsMultipleSelection = true
		
		let longPress : UILongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(collectionViewLongPress(_:)))
		longPress.delaysTouchesBegan = true
		longPress.minimumPressDuration = 0.5
		longPress.delegate = self
		self.collectionView?.addGestureRecognizer(longPress)
		
	}
	
	func configureMapView() {
		let adjustedRegion = mapView.regionThatFits(mapRegion)
		mapView.setRegion(adjustedRegion, animated: false)
		
		let annotation = MKPointAnnotation()
		annotation.coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
		mapView.addAnnotation(annotation)
		
		mapView.setCenter(annotation.coordinate, animated: false)
	}
	
	func displayNoPhotos() {
		if (presentedViewController != nil) {
			// Delay if we're already presenting an alert (eg, onboarding)
			DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
				self.displayNoPhotos()
			}
			return
		}
		let alert = UIAlertController(title: "No Photos", message: "Sorry! We couldn't find any pictures for this location", preferredStyle: UIAlertControllerStyle.alert)
		alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { alertAction in self.activityIndicator.stopAnimating()
			self.navigationItem.title = "Album (No Photos)"
		}))
		alert.addAction(UIAlertAction(title: "Delete Pin", style: UIAlertActionStyle.destructive, handler: { alertAction in self.deletePin()
		}))
		present(alert, animated: true, completion: nil)
	}
	
	// MARK: - Core Data
	fileprivate func setupFetchedResultsController() {
		let fetchRequest:NSFetchRequest<Photo> = Photo.fetchRequest()
		let predicate = NSPredicate(format: "pin == %@", pin)
		fetchRequest.predicate = predicate
		let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
		fetchRequest.sortDescriptors = [sortDescriptor]
		
		// TODO: Figure out "couldn't read cache file to update store info timestamps" error
		// for cache name "\(pin)-photos". For now, made cachename nil
		fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
		fetchedResultsController.delegate = self
		
		do {
			try fetchedResultsController.performFetch()
			if (fetchedResultsController.sections?[0].numberOfObjects == 0) {
				print("PhotoAlbumView - No photos yet for pin, downloading photos")
				downloadPhotosForPin(pin)
			} else {
				deleteAlbumButton.isEnabled = true
			}
		} catch {
			fatalError("PhotoAlbumView - The fetch could not be performed: \(error.localizedDescription)")
		}
	}
	
	@objc fileprivate func deletePressed() {
		if (collectionView.indexPathsForSelectedItems?.count ?? 0 > 0) {
			for path in collectionView.indexPathsForSelectedItems! {
				dataController.viewContext.delete(fetchedResultsController.object(at: path))
			}
		} else {
			let alert = UIAlertController(title: "Delete Album?", message: "Are you sure you want to delete all your photos, and its associated pin?", preferredStyle: UIAlertControllerStyle.alert)
			alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: nil))
			alert.addAction(UIAlertAction(title: "Delete Album", style: UIAlertActionStyle.destructive) { action in
				self.deletePin()
			})
			present(alert, animated: true, completion: nil)
		}
	}
	
	fileprivate func deletePin() {
		if let vc = navigationController?.viewControllers.first as? TravelLocationsMapViewController {
			vc.deletePin(pin)
			pin = nil
			navigationController?.popViewController(animated: true)
		}
	}
	
	// MARK: - Photos
	func deletePhoto(_ photo: Photo){
		dataController.viewContext.delete(photo)
		try? dataController.viewContext.save()
	}
	
	func deleteAllPhotos() {
		let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Photo")
		let predicate = NSPredicate(format: "pin == %@", pin)
		fetchRequest.predicate = predicate
		let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
		do {
			try dataController.viewContext.execute(deleteRequest)
			try? dataController.viewContext.save()
		} catch let error as NSError {
			print("PhotoAlbumView - There was an error with the batch delete: \(error)")
		}
	}
	
	@objc func newCollection(sender: Any) {
		newCollectionButton.isEnabled = false
		newCollectionButton.title = "Fetching Photos..."
		activityIndicator.startAnimating()
		
		deleteAllPhotos()
		deleteAlbumButton.isEnabled = false
		downloadPhotosForPin(pin)
	}
	
	func downloadPhotosForPin(_ pin: Pin){
		flickrClient.downloadPhotosForPin(pin) { photos in
			if photos != nil {
				for photo in photos! {
					if let imageURL = photo.url() {
						let photo = Photo(context: self.dataController.viewContext)
						photo.pin = pin
						photo.url = imageURL.absoluteString
						photo.date = Date()
					}
				}
				// Saving in the block becomes terrifyingly slow - so we save at the end...
				try? self.dataController.viewContext.save()
				// ... but then we must queue up our updates to the collection view,
				// since we can't do a beginUpdates/endUpdates like with a tableView!
				// It'll lock up the UI!
				
				self.newCollectionButton.title = "New Collection"
				// Discourage jammin' on the refresh/delete button by adding a delay
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
					self.newCollectionButton.isEnabled = true
					self.deleteAlbumButton.isEnabled = true
				}
				self.activityIndicator.stopAnimating()
			} else {
				self.deleteAlbumButton.isEnabled = true
				self.displayNoPhotos()
			}
		}
	}
	
	// TODO: Move this to FlickrAPIClient
	fileprivate func downloadDataForPhoto(_ photo: Photo) {
		flickrClient.downloadDataForPhoto(photo) { data in
			if data != nil {
				photo.imageData = data
				try? self.dataController.viewContext.save()
			}
		}
	}
}

// MARK: - CollectionView Delegate
extension PhotoAlbumViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
	// MARK: Delegate Methods
	func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
		let cell = cell as! PhotoAlbumCell
		if let data = fetchedResultsController.object(at: indexPath).imageData {
			// TODO: Check to see if we really need this
			if cell.indexPath == indexPath {
				cell.setImageData(data: data)
			}
		} else {
			self.downloadDataForPhoto(self.fetchedResultsController.object(at: indexPath))
		}
	}
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoAlbumCell", for: indexPath) as! PhotoAlbumCell
		cell.prepareForReuse()
		cell.indexPath = indexPath
		if (selectedIndexPaths.contains(indexPath)){
			cell.isSelected = true
		}
		return cell
	}
	
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return 1 // We should always have just one section
	}
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return fetchedResultsController.sections?[section].numberOfObjects ?? 0
	}
	
	func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
		if let selected = collectionView.indexPathsForSelectedItems {
			if selected.contains(indexPath) {
				if let ip = selectedIndexPaths.index(of: indexPath) {
					selectedIndexPaths.remove(at: ip)
				}
				collectionView.deselectItem(at: indexPath, animated: true)
				return false
			}
		}
		return true
	}
	
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		self.selectedIndexPaths.append(indexPath)
	}
	
	func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
		if let ip = selectedIndexPaths.index(of: indexPath) {
			selectedIndexPaths.remove(at: ip)
		}
	}
	
	// MARK: Convenience Methods
	func enlargeImageAt(_ indexPath: IndexPath) {
		let cell = collectionView.cellForItem(at: indexPath) as! PhotoAlbumCell
		let imageView = UIImageView(image: cell.imageView.image) // copy our image
		imageView.frame = self.view.frame
		imageView.contentMode = .scaleAspectFit
		imageView.backgroundColor = .black
		imageView.contentMode = .center
		imageView.isUserInteractionEnabled = true
		
		let tap = UITapGestureRecognizer(target: self, action: #selector(closeImage))
		imageView.addGestureRecognizer(tap)
		
		UIApplication.shared.keyWindow?.addSubview(imageView)
	}
	
	@objc func closeImage(_ sender: UITapGestureRecognizer) {
		sender.view?.removeFromSuperview()
	}
	
	@objc func collectionViewLongPress(_ recognizer: UIGestureRecognizer) {
		if (recognizer.state == .began) {
			let point = recognizer.location(in: self.collectionView)
			if let indexPath = collectionView?.indexPathForItem(at: point) {
				enlargeImageAt(indexPath)
			}
		}
	}
}

// MARK: - FetchedResultsController Delegate
extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
	// Notice we have to set up block operations in order to avoid locking the UI
	// THIS was VERY helpful: https://stackoverflow.com/questions/20554137/nsfetchedresultscontollerdelegate-for-collectionview/20554673#20554673
	func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
		// If we have deleted our pin, we don't want any of these to trigger. We're only interested in Photos
		if anObject is Photo && self.pin != nil {
			let operation: BlockOperation
			switch type {
			case .insert:
				operation = BlockOperation { self.collectionView?.insertItems(at: [newIndexPath!]) }
				break
			case .delete:
				operation = BlockOperation {
					self.collectionView?.deleteItems(at: [indexPath!])
					if let ip = self.selectedIndexPaths.index(of: indexPath!) {
						self.selectedIndexPaths.remove(at: ip)
					}
				}
				break
			case .update:
				operation = BlockOperation { self.collectionView?.reloadItems(at: [indexPath!]) }
			case .move:
				operation = BlockOperation { self.collectionView?.moveItem(at: indexPath!, to: newIndexPath!) }
			}
			blockOperations.append(operation)
		}
		
	}
	
	func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		blockOperations.removeAll(keepingCapacity: false)
	}
	
	func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		if (self.pin != nil) {
			collectionView.performBatchUpdates({
				self.blockOperations.forEach { $0.start() }
			}, completion: { finished in
				self.blockOperations.removeAll(keepingCapacity: false)
			})
		}
	}
}



