//
//  InterfaceController.swift
//  VimoHeartRate WatchKit App Extension
//
//  Created by Ethan Fan on 6/25/15.
//  Copyright © 2015 Vimo Lab. All rights reserved.
//

import WatchKit
import Foundation
import HealthKit


class InterfaceController: WKInterfaceController, HKWorkoutSessionDelegate {
    
    @IBOutlet weak var label: WKInterfaceLabel!
    @IBOutlet weak var deviceLabel : WKInterfaceLabel!
    @IBOutlet weak var heart: WKInterfaceImage!
    
    
    let healthStore = HKHealthStore()
    let heartRateType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)!
    
    // define the activity type and location
    let workoutSession = HKWorkoutSession(activityType: HKWorkoutActivityType.CrossTraining, locationType: HKWorkoutSessionLocationType.Indoor)
    let heartRateUnit = HKUnit(fromString: "count/min")
    // the device sensor location from the devcie mananger
    let deviceSensorLocation = HKHeartRateSensorLocation.Other
    // the device sensor location returned from HealthKit
    let location = HKHeartRateSensorLocation.Other
    
    var anchor = 0
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        workoutSession.delegate = self
    }
    
    override func willActivate() {
        super.willActivate()
        
        if HKHealthStore.isHealthDataAvailable() != true {
            self.label.setText("not availabel")
            return
        }
        
        let dataTypes = NSSet(object: heartRateType) as! Set<HKObjectType>
        
        healthStore.requestAuthorizationToShareTypes(nil, readTypes: dataTypes) { (success, error) -> Void in
            
            if success != true {
                self.label.setText("not allowed")
            }
        }
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    
    func workoutSession(workoutSession: HKWorkoutSession, didChangeToState toState: HKWorkoutSessionState, fromState: HKWorkoutSessionState, date: NSDate){
        
        switch toState{
        case .Running:
            self.workoutDidStart(date)
        case .Ended:
            self.workoutDidEnd(date)
        default:
            print("Unexpected state \(toState)")
        }
        
    }
    
    func workoutSession(workoutSession: HKWorkoutSession, didFailWithError error: NSError){
        
    }
    
    func workoutDidStart(date : NSDate){
        
        let query = createHeartRateStreamingQuery(date)
        
        self.healthStore.executeQuery(query)
    }
    
    
    func workoutDidEnd(date : NSDate){
        
        let query = createHeartRateStreamingQuery(date)
        self.healthStore.stopQuery(query)
        self.label.setText("Stop")
    }
    
    // =========================================================================
    // MARK: - Actions
    
    @IBAction func startBtnTapped() {
        
        
        self.healthStore.startWorkoutSession(self.workoutSession) { (success, error) -> Void in
            // ...
        }
        
    }
    
    
    @IBAction func stopBtnTapped() {
        
        self.healthStore.stopWorkoutSession(self.workoutSession) { (success, error) -> Void in
            // ...
        }
        
    }
    
    func createHeartRateStreamingQuery(workoutStartDate: NSDate) ->HKQuery{
        
        // adding prdicate will not work
        //let predicate = HKQuery.predicateForSamplesWithStartDate(workoutStartDate, endDate: nil, options: HKQueryOptions.None)
        
        var anchorValue = Int(HKAnchoredObjectQueryNoAnchor)
        if anchor != 0 {
            anchorValue = self.anchor
        }
        
        let sampleType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)
        
        let heartRateQuery = HKAnchoredObjectQuery(type: sampleType!, predicate: nil, anchor: anchorValue, limit: 0) { (query, sampleObjects, deletedObjects, newAnchor, error) -> Void in
            
            self.anchor = anchorValue
            self.updateHeartRate(sampleObjects)
        }
        
        heartRateQuery.updateHandler = {(query, samples, deleteObjects, newAnchor, error) -> Void in
            self.anchor = newAnchor
            self.updateHeartRate(samples)
        }
        
        return heartRateQuery
    }
    
    func updateHeartRate(samples: [HKSample]?){
        
        guard let heartRateSamples = samples as?[HKQuantitySample] else {return}
        
        dispatch_async(dispatch_get_main_queue()){
            
            let sample = heartRateSamples.first
            
            let value = sample!.quantity.doubleValueForUnit(self.heartRateUnit)
            
            self.label.setText(String(UInt16(value)))
            
            
            // retrieve source from sample
            let name = sample!.sourceRevision.source.name
            self.updateDeviceName(name)
            self.animateHeart()
            
        }
    }
    
    func updateDeviceName(deviceName: String) {
        
        self.deviceLabel.setText(deviceName)
        
    }
    
    func animateHeart() {
        self.animateWithDuration(0.5) { () -> Void in
            self.heart.setWidth(60)
            self.heart.setHeight(90)
        }
        
        let when = dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * double_t(NSEC_PER_SEC)))
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        dispatch_after(when, queue) { () -> Void in
            dispatch_async(dispatch_get_main_queue(), {
                self.animateWithDuration(0.5, animations: { () -> Void in
                    self.heart.setWidth(50)
                    self.heart.setHeight(80)
                })
            })
        }
    }
    
}

