//
//  NotesView.swift
//  RemindMe
//
//  Created by Charel Felten on 02/07/2021.
//

import SwiftUI
import WidgetKit
import Combine

struct NotesView: View {
  
  @Environment(\.managedObjectContext) private var viewContext
  
  @ObservedObject var config: Config
  
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Note.timestamp, ascending: true)],
    animation: .default
  ) private var notes: FetchedResults<Note>
  
  // new note
  @State private var newNoteContent: String = ""
  @FocusState private var newNoteIsFocused: Bool
  
  // edit note
  @State private var editNote: Note? = nil
  @State private var editNoteContent: String = ""
  @FocusState private var editNoteIsFocused: Bool
  
  // custom date note
  @State private var customDateNote: Note? = nil
  @State private var showCustomDateSheet = false
  @State private var customDate: Date = Date()
  
  // dark mode
  @Environment(\.colorScheme) var colorScheme
  
  func submitNewNote() {
    Note.add(content: newNoteContent)
    newNoteContent = ""
    newNoteIsFocused = false
  }
  
  func editExistingNote(note: Note?) {
    guard let note else { return }
    note.content = editNoteContent
    PersistenceController.shared.save()
    editNoteContent = ""
    editNoteIsFocused = false
    editNote = nil
  }
  
//  func editCell(
//    noteContent: Binding<String>,
//    submitFunc: @escaping () -> (),
//    focus: FocusState<Bool>.Binding
//  ) -> some View {
//    return HStack {
//      TextField("New Note", text: noteContent)
//      .onSubmit(submitFunc)
//      .focused(focus)
//      if (!noteContent.isEmpty) {
//        Button(action: submitFunc) {
//          Image(systemName: "checkmark")
//        }
//      }
//    }
//  }
  
  var body: some View {
    List {
      ForEach(notes) { note in
        if (note != editNote) {
          OneNoteView(config: config, note: note)
          
          // context menu for the note, cant be extracted because it works with both editNote and customDateNote
          .contextMenu {
            // bug in ios15: context menu may show outdated information
            VStack {
              Label("Created on: \(note.timestamp ?? Date(), formatter: Note.dateFormatter)", systemImage: "calendar")
              Label("Reminders: \(note.priority.getIntervalDescription())", systemImage: "bell")
              Button {
                customDateNote = note
                showCustomDateSheet = true
              } label: {
                Label("Create Custom Reminder", systemImage: "calendar.badge.plus")
              }
              Button {
                editNote = note
                editNoteContent = note.content ?? newNoteContent
                editNoteIsFocused = true
              } label: {
                Label("Edit Note", systemImage: "pencil")
              }
            }
          }
          
          // the background. We could add a backgroudn to the note view,
          // but then it does not fill the whole row
          // we use a ZStack to get rid of the ugly default background
          // has to come after the context menu for some reason
          .listRowBackground(
            ZStack {
              colorScheme == .dark ? Color.black : Color.white
              note.getBackgroundColor()
            }
          )
          
          // swipe actions (cant be extracted, because they need to be in a list)
          .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
              note.delete()
            } label: {
              Label("Delete", systemImage: "trash")
            }
          }
        
          
        } else { // in the case the note is to be edited
          HStack {
            TextField(editNoteContent, text: $editNoteContent)
            .onSubmit({editExistingNote(note: editNote)})
            .focused($editNoteIsFocused)
            if (!editNoteContent.isEmpty) {
              Button(action: {editExistingNote(note: editNote)}) {
                Image(systemName: "checkmark")
              }
            }
          }
        } // close edit note if-else
      } // close for-each note
      
      if editNote == nil {
        HStack {
          TextField("New Note", text: $newNoteContent)
          .onSubmit(submitNewNote)
          .focused($newNoteIsFocused)
          if (!newNoteContent.isEmpty) {
            Button(action: submitNewNote) {
              Image(systemName: "checkmark")
            }
          }
        }
      } // close if of showing new note cell
    } // close list
    
    .listStyle(InsetGroupedListStyle())
    
    .sheet(isPresented: $showCustomDateSheet) {
      NavigationView{
        VStack {
          DatePicker("Reminder on", selection: $customDate)
        }
        .padding()
        .navigationBarItems(leading: Button(action: {
          showCustomDateSheet.toggle()
        }) {
          Text("Cancel")
        }, trailing: Button(action: {
          if let note = customDateNote {
            note.updatePriority(optionalDate: customDate)
          }
          customDateNote = nil
          showCustomDateSheet.toggle()
        }) {
          Text("Add")
        }
        )
      }
    } // close custom note sheet
  } // close body
}

struct NotesView_Previews: PreviewProvider {
  static var previews: some View {
    NotesView(
      config: Config()
    )
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
  }
}
