import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    let username: String
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phoneNumber: String = ""
    @State private var dob: Date? = nil
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var message: String? = nil
    @State private var messageColor: Color = .red
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var pictureData: Data? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    PhotosPicker(selection: $selectedPhoto, matching: .any(of: [.images, .videos])) {
                        ZStack(alignment: .bottomTrailing) {
                            Group {
                                if let pictureData,
                                   let uiImage = UIImage(data: pictureData) {
                                    Image(uiImage: uiImage)
                                } else {
                                    Image("default-profile")
                                }
                            }
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())

                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 24))
                                .padding(4)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                                .offset(x: -4, y: -4)
                        }
                    }
                    .onChange(of: selectedPhoto) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                pictureData = data
                            }
                        }
                    }

                    Text("Tap image to edit")
                        .font(.caption)
                        .foregroundColor(.gray)

                    TextField("First Name", text: $firstName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    TextField("Last Name", text: $lastName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    TextField("Phone Number", text: $phoneNumber)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.phonePad)
                        .padding(.horizontal)
                        .onChange(of: phoneNumber) { _, newValue in
                            phoneNumber = formatPhoneNumber(newValue)
                        }

                    DatePicker("Date of Birth", selection: Binding(
                        get: { dob ?? Date() },
                        set: { dob = $0 }
                    ), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "en_US"))
                        .padding(.horizontal)

                    Button("Save Info") {
                        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)

                        if trimmedFirst.isEmpty || trimmedLast.isEmpty || trimmedPhone.isEmpty || dob == nil {
                            showMessage("All fields are required", color: .red)
                        } else if DatabaseManager.shared.updateUser(username: username, firstName: trimmedFirst, lastName: trimmedLast, phoneNumber: trimmedPhone, dob: dateFormatter.string(from: dob!), picture: pictureData) {
                            showMessage("Information updated", color: .green)
                        } else {
                            showMessage("Unable to update information", color: .red)
                        }
                    }
                    .padding(.top)

                    Divider().padding(.vertical)

                    SecureField("Current Password", text: $currentPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    SecureField("New Password", text: $newPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    Button("Update Password") {
                        if currentPassword.isEmpty || newPassword.isEmpty {
                            showMessage("Current and new passwords are required", color: .red)
                        } else if confirmPassword.isEmpty {
                            showMessage("Please confirm your new password", color: .red)
                        } else if newPassword != confirmPassword {
                            showMessage("Passwords do not match", color: .red)
                        } else if DatabaseManager.shared.updatePassword(username: username, currentPassword: currentPassword, newPassword: newPassword) {
                            showMessage("Password updated", color: .green)
                            currentPassword = ""
                            newPassword = ""
                            confirmPassword = ""
                        } else {
                            showMessage("Current password incorrect", color: .red)
                        }
                    }
                    .padding(.top)

                    if let message = message {
                        Text(message)
                            .foregroundColor(messageColor)
                    }
                }
                .padding(.bottom)
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
            }
            .onAppear {
                if let member = DatabaseManager.shared.fetchUser(username: username) {
                    firstName = member.firstName
                    lastName = member.lastName
                    phoneNumber = member.phoneNumber
                    dob = dateFormatter.date(from: member.dob)
                    pictureData = member.picture
                }
            }
        }
    }

    private func showMessage(_ text: String, color: Color) {
        message = text
        messageColor = color
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            message = nil
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }

    private func formatPhoneNumber(_ number: String) -> String {
        let digits = number.filter { $0.isNumber }
        let limited = String(digits.prefix(10))
        let area = limited.prefix(3)
        let middle = limited.dropFirst(3).prefix(3)
        let last = limited.dropFirst(6)
        var result = ""
        if !area.isEmpty {
            result += "(" + area
            if area.count == 3 { result += ")" }
        }
        result += middle
        if !last.isEmpty {
            result += "-" + last
        }
        return result
    }
}

#Preview {
    ProfileView(username: "USER")
}

