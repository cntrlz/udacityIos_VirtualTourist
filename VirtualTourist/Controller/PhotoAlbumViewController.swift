//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by benchmark on 8/2/18.
//  Copyright © 2018 Viktor Lantos. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import Alamofire

class PhotoAlbumViewController: UICollectionViewController {
	// IBOutlets
	@IBOutlet weak var cv: UICollectionView!
	
	// UI Elements
	var newCollectionButton: UIBarButtonItem = UIBarButtonItem()
	var activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView()
	
	// Model
	var flickrClient:FlickrAPIClient!
	var dataController: DataController!
	var fetchedResultsController:NSFetchedResultsController<Photo>!
	
	// Local properties
	var pin: Pin!
	var queued: [Photo] = []

	// MARK: - View
	override func viewDidLoad() {
		setupFetchedResultsController()
		configureCollectionView()
		configureToolbarItems()
		configureActivityIndicator()
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
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
	fileprivate func configureCollectionView() {
		let flow = UICollectionViewFlowLayout()
		let itemSpacing: CGFloat = 2
		let minimumCellWidth: CGFloat = 120
		let collectionViewWidth = collectionView!.bounds.size.width
		
		let itemsPerLine = CGFloat(Int((collectionViewWidth - CGFloat(Int(collectionViewWidth / minimumCellWidth) - 1) * itemSpacing) / minimumCellWidth))
		let width = collectionViewWidth - itemSpacing * (itemsPerLine - 1)
		let cellWidth = floor(width / itemsPerLine)
		let realItemSpacing = itemSpacing + (width / itemsPerLine - cellWidth) * itemsPerLine / (itemsPerLine - 1)
		
		let edgeSpacing : CGFloat = 4
		flow.sectionInset = UIEdgeInsets(top: edgeSpacing, left: edgeSpacing, bottom: edgeSpacing, right: edgeSpacing)
		flow.itemSize = CGSize(width: cellWidth - edgeSpacing, height: cellWidth - edgeSpacing)
		flow.minimumInteritemSpacing = realItemSpacing
		flow.minimumLineSpacing = realItemSpacing
		
		collectionView?.setCollectionViewLayout(flow, animated: false)
	}
	
	func displayNoPhotos() {
		let alert = UIAlertController(title: "No Photos", message: "Sorry! We couldn't find any pictures for this location", preferredStyle: UIAlertControllerStyle.alert)
		alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { alertAction in self.activityIndicator.stopAnimating()
			self.navigationItem.title = "Album (No Photos)"
		}))
		self.present(alert, animated: true, completion: nil)
	}
	
	// MARK: - Core Data
	fileprivate func setupFetchedResultsController() {
		let fetchRequest:NSFetchRequest<Photo> = Photo.fetchRequest()
		let predicate = NSPredicate(format: "pin == %@", pin)
		fetchRequest.predicate = predicate
		let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
		fetchRequest.sortDescriptors = [sortDescriptor]
		
		// TODO: Figure out "couldn't read cache file to update store info timestamps" error
		// for cache name "\(pin)-photos"
		// For now, made cachename nil
		fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
		fetchedResultsController.delegate = self
		
		do {
			try fetchedResultsController.performFetch()
			if(fetchedResultsController.sections?[0].numberOfObjects == 0){
				print("PhotoAlbumView - No photos yet for pin, downloading photos")
				self.downloadPhotosForPin(pin)
			}
		} catch {
			fatalError("PhotoAlbumView - The fetch could not be performed: \(error.localizedDescription)")
		}
	}
	
	// MARK: - Photos
	func deletePhoto(at indexPath: IndexPath) {
		let photoToDelete = fetchedResultsController.object(at: indexPath)
		dataController.viewContext.delete(photoToDelete)
		try? dataController.viewContext.save()
	}
	
	@objc func newCollection(sender: Any) {
		self.newCollectionButton.isEnabled = false
		self.newCollectionButton.title = "Fetching Photos..."
		self.activityIndicator.startAnimating()
		
		// TODO: This locks up the UI. Do a background deal
		var photos = 0
		for photo in fetchedResultsController.fetchedObjects ?? [] {
			photos += 1
			deletePhoto(at: fetchedResultsController.indexPath(forObject: photo)!)
		}
		
		downloadPhotosForPin(self.pin)
	}
	
	func downloadPhotosForPin(_ pin: Pin){
		flickrClient.getPhotosForLatitude(pin.latitude, longitude: pin.longitude){ photos in
			if let photos = photos {
				for photo in photos {
					if let imageURL = photo.url() {
						let photo = Photo(context: self.dataController.viewContext)
						photo.pin = pin
						photo.url = imageURL.absoluteString
						photo.date = Date()
						try? self.dataController.viewContext.save()
					}
				}
				
				// Because fetching can be slow, user might press the new collection button
				// twice, accidentally. Having it enable after a delay prevents this.
				self.newCollectionButton.title = "New Collection"
				DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
					self.newCollectionButton.isEnabled = true
				}
				self.activityIndicator.stopAnimating()
			} else {
				print("PhotoAlbumView - Could not download photos for pin or no photos")
				self.displayNoPhotos()
			}
		}
	}
	
	// TODO: Move this to FlickrAPIClient
	fileprivate func downloadDataForPhoto(_ photo: Photo) {
		if queued.contains(photo) {
			print("PhotoAlbumView - Photo queued for download already. CollectionView delegate methods can fire multiple times.")
			return
		}
		if let url = photo.url {
			Alamofire.request(url).responseData { (response) in
				if response.error == nil {
					if let data = response.data {
						photo.imageData = data
						try? self.dataController.viewContext.save()
					}
				} else {
					if let index = self.queued.index(of: photo) {
						self.queued.remove(at: index)
					}
					print("PhotoAlbumView - Alamofire couldn't DL image")
				}
			}
			queued.append(photo)
		} else {
			if let index = queued.index(of: photo) {
				queued.remove(at: index)
			}
			print("PhotoAlbumView -  could not download data for photo with no url")
		}
	}
}

extension PhotoAlbumViewController: UICollectionViewDelegateFlowLayout {
	override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
		let cell = cell as! PhotoAlbumCell
		if let data = fetchedResultsController.object(at: indexPath).imageData {
			// TODO: Check to see if we really need this
			if cell.indexPath == indexPath {
				cell.setImageData(data: data)
			} else {
				//	print("CFRAIP - \(indexPath.row) - index paths do not match, not setting image")
			}
		} else {
			downloadDataForPhoto(fetchedResultsController.object(at: indexPath))
		}
	}
	override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoAlbumCell", for: indexPath) as! PhotoAlbumCell
		cell.prepareForReuse()
		cell.indexPath = indexPath
		return cell
	}
	
	override func numberOfSections(in collectionView: UICollectionView) -> Int {
		return 1 // We should always have just one section
	}
	
	override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return fetchedResultsController.sections?[section].numberOfObjects ?? 0
	}
	
	override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		deletePhoto(at: indexPath)
	}
}

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
	func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
		switch type {
		case .insert:
			self.collectionView?.insertItems(at: [newIndexPath!])
			break
		case .delete:
			self.collectionView?.deleteItems(at: [indexPath!])
			break
		case .update:
			self.collectionView?.reloadItems(at: [indexPath!])
		case .move:
			self.collectionView?.moveItem(at: indexPath!, to: newIndexPath!)
		}
	}
}



