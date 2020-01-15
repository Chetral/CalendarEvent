//
//  CalendarEvents.swift
//
//  Created by Marco Pirola on 05/10/2019.
//  Copyright © 2019 Marco Pirola. All rights reserved.
//


import UIKit
import EventKit
import EventKitUI

class EventsCalendarManager: NSObject {
    
    
    var eventStore: EKEventStore!
    override init() {
        eventStore = EKEventStore()
    }
    
    
    // Request access to the Calendar
    
        func requestAccess(completion: @escaping EKEventStoreRequestAccessCompletionHandler) {
            eventStore.requestAccess(to: EKEntityType.event) { (accessGranted, error) in
                completion(accessGranted, error)
            }
        }
    
    
    // Request access to the Reminder
    
        func requestAccessReminder(completion: @escaping EKEventStoreRequestAccessCompletionHandler) {
            eventStore.requestAccess(to: EKEntityType.reminder) { (accessGranted, error) in
                completion(accessGranted, error)
            }
        }
    
    // Get Calendar auth status
    
    func getAuthorizationStatus() -> EKAuthorizationStatus {
        return EKEventStore.authorizationStatus(for: EKEntityType.event)
    }
    
    // Get Reminder auth status
    
    func getAuthorizationReminder() -> EKAuthorizationStatus {
        return EKEventStore.authorizationStatus(for: EKEntityType.reminder)
    }
    
    
    // Check Calendar permissions auth status
    // Try to add an event to the calendar if authorized
            
    func addEventToCalendar(event: EKEvent) {
        
        let authStatus = getAuthorizationStatus()
        switch authStatus {
            case .authorized:
                self.addEvent(event: event)
            case .notDetermined:
                //Auth is not determined
                //We should request access to the calendar
                requestAccess { (accessGranted, error) in
                    if accessGranted {
                        self.addEvent(event: event)
                    } else {
                        // Auth denied, we should display a popup
                        
                    }
                }
            case .denied, .restricted:
                // Auth denied or restricted, we should display a popup
                
            @unknown default:
                print("Error unknown!")
        }
    }
    
    
    // Try to save an event to the calendar
    
    private func addEvent(event: EKEvent) {
        var ok: Bool = true

        if !eventAlreadyExists(event: event) {
            do {
                try eventStore.save(event, span: .thisEvent, commit: true)
            } catch {
                // Error while trying to create event in calendar
                print("error creating Event")
                ok = false
            }
            if ok == true {
                print("Event created")
            }
        } else {
            print("event already exist")
        }
    }
    
    // Check if the event was already added to the calendar
    
    private func eventAlreadyExists(event eventToAdd: EKEvent) -> Bool {
        let predicate = eventStore.predicateForEvents(withStart: eventToAdd.startDate, end: eventToAdd.endDate, calendars: nil)
        let existingEvents = eventStore.events(matching: predicate)
        
        let eventAlreadyExists = existingEvents.contains { (event) -> Bool in
            return eventToAdd.title == event.title && event.startDate == eventToAdd.startDate && event.endDate == eventToAdd.endDate
        }
        return eventAlreadyExists
    }
    
    
    // the exemple create 3 events. Starting event (arrivo) at datada at 4PM, the event itself, End of the event (partenza) at Dataa at 9AM as it may occurs with a long meeting
    func createEvent (titolo: String, datada: Date, dataa: Date, note: String) {
            
            var idcal: String? = nil
            let datadas = midnight(data: datada)
            let dataas = midnight(data: dataa)
            let event = EKEvent.init(eventStore: eventStore)
            let arrivo = EKEvent.init(eventStore: eventStore)
            let partenza = EKEvent.init(eventStore: eventStore)
        
            event.title = titolo + " " + note
            if datadas == dataas {
                event.startDate = datadas
                event.endDate = dataas
            } else {
                event.startDate = Calendar.current.date(byAdding: .day, value: 1, to: datada)
                event.endDate = Calendar.current.date(byAdding: .day, value: -1, to: dataa)
            }
            event.notes = note
            event.isAllDay = true
            
            // search for a calendar named as the notes, it can be the name of a office or a customer
            idcal = self.retriveCalendar(nome: event.notes!, event: event)
            if (idcal == nil) {
                // if the claendar do not exist, create it.
                // note, if you want to use the dafault calendar e very time you need to modify retriveCalendar func
                idcal = self.createCalendar(nome: event.notes!, event: event)
            }
            event.calendar = eventStore.calendar(withIdentifier: idcal!)
     
            addEventToCalendar(event: event)
            
        
            arrivo.title = "Start " + titolo + " at " + note
            arrivo.startDate = Calendar.current.date(byAdding: .hour, value: 16, to: datadas)
            arrivo.endDate = Calendar.current.date(byAdding: .hour, value: 17, to: datadas)
            arrivo.notes = "Start at " + note
            arrivo.calendar = event.calendar

            addEventToCalendar(event: arrivo)
        
            partenza.title = "Leaving " + titolo + " from " + note
            partenza.startDate = Calendar.current.date(byAdding: .hour, value: 8, to: dataas)
            partenza.endDate = Calendar.current.date(byAdding: .hour, value: 9, to: dataas)
            partenza.notes = "Leaving from " + note
            partenza.calendar = event.calendar

            addEventToCalendar(event: partenza)
            
    }
    
    func createCalendar(nome: String, event: EKEvent) -> String?{
        // Use Event Store to create a new calendar instance
        // Configure its title
        
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        
        // Probably want to prevent someone from saving a calendar
        // if they don't type in a name...
        newCalendar.title = nome
        
         // calendari che accettano reminders
        let eventInEventStore = eventStore.calendars(for: .event)
        var trovato: Bool = false
        // cerco un source
        var cal = EKCalendar(for: .event, eventStore: eventStore)
        for i in 0...eventInEventStore.count - 1 {
            cal = eventInEventStore[i]
            switch cal.source.sourceType.rawValue {
                case EKSourceType.local.rawValue :
                    trovato = true
                case EKSourceType.calDAV.rawValue :
                    trovato = true
                case EKSourceType.subscribed.rawValue :
                    trovato = true
                case EKSourceType.exchange.rawValue :
                    trovato = true
                case EKSourceType.mobileMe.rawValue :
                    trovato = true
                default:
                    print("error")
            }
            if trovato {
                break
            }
        }
        
        newCalendar.source = cal.source
        if newCalendar.source == nil {
            newCalendar.source =  eventStore.defaultCalendarForNewEvents?.source
        }
        
        // Save the calendar using the Event Store instance
        do {
            try eventStore.saveCalendar(newCalendar, commit: true)
            UserDefaults.standard.set(newCalendar.calendarIdentifier, forKey: nome)
        } catch {
            print("error creating calendar")
        }
        return newCalendar.calendarIdentifier
    }
    
    func retriveCalendar(nome: String, event: EKEvent) -> String? {
        var calArray: [EKCalendar]
        var idc: String? = nil
        // if you want to use default calendar simply use:
        //idc = eventStore.defaultCalendarForNewEvents?.calendarIdentifier
        calArray = eventStore.calendars(for: .event)
        
        for cale in calArray {
            if cale.title == nome {
                idc = cale.calendarIdentifier
                break
            }
        }
      return idc
    }
    
    // that's a trick. the date in swift is always with time, if you want to create an event to a given time first you have to return to midnight (mezzanotte means midnight)
    func midnight(data: Date) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 00:00:00 Z"
        let myString = formatter.string(from: data)
        var mezzanotte = formatter.date(from: myString)!
        formatter.dateFormat = "dd-MM-yyyy 00:00:00 Z"
        // when you format the date it get the GMT time. To reach midnight you need to add you timezone
        let timeZone = getCurrentTimeZone()
        mezzanotte = Calendar.current.date(byAdding: .hour, value: timeZone, to: mezzanotte)!
        return mezzanotte
    }
    
    func deleteEvent(titolo: String, datada: Date, dataa: Date){
        let predicate = eventStore.predicateForEvents(withStart: datada, end: dataa, calendars: nil)
        let existingEvents = eventStore.events(matching: predicate)
        var event: EKEvent? = nil
        if existingEvents.count > 0 {
            for i in 0...existingEvents.count - 1 {
                event = existingEvents[i]
                if titolo == event?.title && event?.startDate == datada && event?.endDate == datada {
                    break
                }
            }
            do {
                try eventStore.remove(event!, span: .thisEvent, commit: true)
            } catch {
                // Error while trying to remove event from calendar
            print("l'evento non e' stato cancellato")
            }
        }
    }
        
    
    func getCurrentTimeZone() -> Int {
            let localTimeZoneAbbreviation: Int = TimeZone.current.secondsFromGMT()
            let items = (localTimeZoneAbbreviation / 3600)
            return items
    }
    
    // this is for Remiders
    func createCalendarReminder(tipo: String) -> String?{
        // Use Event Store to create a new calendar instance
        // Configure its title
        
        let newCalendar = EKCalendar(for: .reminder, eventStore: eventStore)
        
        // Probably want to prevent someone from saving a calendar
        // if they don't type in a name...
        newCalendar.title = tipo
        
        // calendari che accettano reminders
        let reminderInEventStore = eventStore.calendars(for: .reminder)
        var trovato: Bool = false
        // cerco un source
        var cal = EKCalendar(for: .reminder, eventStore: eventStore)
        for i in 0...reminderInEventStore.count - 1 {
            cal = reminderInEventStore[i]
            switch cal.source.sourceType.rawValue {
                case EKSourceType.local.rawValue :
                    trovato = true
                case EKSourceType.calDAV.rawValue :
                    trovato = true
                case EKSourceType.subscribed.rawValue :
                    trovato = true
                case EKSourceType.exchange.rawValue :
                    trovato = true
                case EKSourceType.mobileMe.rawValue :
                    trovato = true
                default:
                    print("error")
            }
            if trovato {
                break
            }
        }
        
        newCalendar.source = cal.source
        if newCalendar.source == nil {
            newCalendar.source =  eventStore.defaultCalendarForNewReminders()?.source
        }
        
        // Save the calendar using the Event Store instance
        do {
            try eventStore.saveCalendar(newCalendar, commit: true)
        } catch {
            print("error creqting calendar for reminder")
        }
        return newCalendar.calendarIdentifier
    }
    
    func createReminder (nome: String, stanza: String, giorni: Int, data: Date) {
        
        var idcal: String? = nil
        let promemoria = EKReminder.init(eventStore: eventStore)
        let dat: Date = Calendar.current.date(byAdding: .hour, value: 8, to: midnight(data: data))!
        // you can create different list of reminders (meeting, lunch, dinners...)
        idcal = self.retriveCalendarReminder(tipo: tipo)
        if (idcal == nil) {
            idcal = self.createCalendarReminder(tipo: tipo)
        }
        
        // if needed according to variable tipo you can change the title of the reminder
        promemoria.title = "Meeting with \(nome) at \(stanza)"
        
        //create an alarm x day (giorni) starting from today
        let alarm = EKAlarm(absoluteDate: Calendar.current.date(byAdding: .day, value: giorni, to: dat)!)
        // add the alarm to the reminder
        promemoria.addAlarm(alarm)
        // set the reminder in the right list
        promemoria.calendar = eventStore.calendar(withIdentifier: idcal!)

        
        addReminderToCalendar(promemoria: promemoria)
        
       }
    
    
    func retriveCalendarReminder(tipo: String) -> String? {
        var calArray: [EKCalendar]
        var idc: String? = nil
        calArray = eventStore.calendars(for: .reminder)
        
        // if you want to use default calendar simply use:
        //idc = eventStore.defaultCalendarForNewReminders?.calendarIdentifier
        
        
        for cale in calArray {
            if cale.title == tipo {
                idc = cale.calendarIdentifier
                break
            }
        }
      return idc
    }
    
    // Try to add a reminder to the calendar if authorized
            
    func addReminderToCalendar(promemoria: EKReminder) {
        
        let authStatus = getAuthorizationReminder()
        switch authStatus {
            case .authorized:
                self.addReminder(promemoria: promemoria)
            case .notDetermined:
                //Auth is not determined
                //We should request access to the calendar
                requestAccessReminder { (accessGranted, error) in
                    if accessGranted {
                        self.addReminder(promemoria: promemoria)
                    } else {
                        // Auth denied, we should display a popup
                        
                    }
                }
            case .denied, .restricted:
                // Auth denied or restricted, we should display a popup
                
            @unknown default:
                print("Error unknown!")
        }
    }
    
    
    // Try to save a reminder to the calendar
    
    private func addReminder(promemoria: EKReminder) {
        
        do {
            try eventStore.save(promemoria, commit: true)
        } catch {
            // Error while trying to create event in calendar
            print("reminder not created")
            
        }
 
    }

    func deleteReminder(nome: String, stanza: String, tipo: String){
        let idc = retriveCalendarReminder(tipo: tipo)
        // if the list do not exist, so the reminder
        if idc != nil {
            let pre = eventStore.predicateForReminders(in: [eventStore.calendar(withIdentifier: idc!)!])
            let titolo = "Meeting with \(nome) at \(stanza)"
            eventStore.fetchReminders(matching: pre) { foundReminders in

                if foundReminders?.count ?? 0 > 0 {
                    for i in 0...foundReminders!.count - 1 {
                        if foundReminders![i].title == titolo {
                            try? self.eventStore.remove((foundReminders![i]), commit: true)
                        }
                    }
                }
            }
        }
    }
}

    // EKEventEditViewDelegate
    extension EventsCalendarManager: EKEventEditViewDelegate {
        
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            controller.dismiss(animated: true, completion: nil)
        }
    }
    
