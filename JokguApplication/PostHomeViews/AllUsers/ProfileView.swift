import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    let username: String
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var dob: Date? = nil
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var message: String? = nil
    @State private var messageColor: Color = .red
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var pictureData: Data? = nil
    @State private var pictureURL: String? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    PhotosPicker(selection: $selectedPhoto, matching: .any(of: [.images, .videos])) {
                        if let pictureData,
                           let uiImage = UIImage(data: pictureData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else if let pictureURL {
                            if let url = URL(string: pictureURL),
                               let scheme = url.scheme,
                               (scheme == "http" || scheme == "https") {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Image("default-profile")
                                            .resizable()
                                            .scaledToFill()
                                    }
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            } else if let data = Data(base64Encoded: pictureURL),
                                      let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Image("default-profile")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            }
                        } else {
                            Image("default-profile")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        }
                    }
                    .onChange(of: selectedPhoto) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            pictureData = data
                            pictureURL = nil
                            }
                        }
                    }

                    TextField("First Name", text: $firstName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    TextField("Last Name", text: $lastName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

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
                        if trimmedFirst.isEmpty || trimmedLast.isEmpty || dob == nil {
                            showMessage("All fields are required", color: .red)
                        } else {
                            Task {
                                do {
                                    try await DatabaseManager.shared.updateUser(username: username, firstName: trimmedFirst, lastName: trimmedLast, dob: dateFormatter.string(from: dob!), picture: pictureData)
                                    await MainActor.run {
                                        showMessage("Information updated", color: .green)
                                    }
                                } catch {
                                    await MainActor.run {
                                        showMessage("Unable to update information", color: .red)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top)

                    Divider().padding(.vertical)

                    SecureField("Current Password", text: $currentPassword)
                        // Use a content type that prevents iOS from offering
                        // strong password suggestions when editing the current
                        // password field. Without this, the system can overlay
                        // a "strong password" suggestion view that blocks user
                        // input.
                        .textContentType(.oneTimeCode)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    SecureField("New Password", text: $newPassword)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    Button("Update Password") {
                        if currentPassword.isEmpty || newPassword.isEmpty {
                            showMessage("Current and new passwords are required", color: .red)
                        } else if confirmPassword.isEmpty {
                            showMessage("Please confirm your new password", color: .red)
                        } else if newPassword != confirmPassword {
                            showMessage("Passwords do not match", color: .red)
                        } else {
                            Task {
                                do {
                                    try await DatabaseManager.shared.updatePassword(username: username, currentPassword: currentPassword, newPassword: newPassword)
                                    await MainActor.run {
                                        showMessage("Password updated", color: .green)
                                        currentPassword = ""
                                        newPassword = ""
                                        confirmPassword = ""
                                    }
                                } catch {
                                    await MainActor.run {
                                        if (error as NSError).domain == "InvalidPassword" {
                                            showMessage("Current password incorrect", color: .red)
                                        } else {
                                            showMessage("Unable to update password", color: .red)
                                        }
                                    }
                                }
                            }
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
                Task {
                    if let member = try? await DatabaseManager.shared.fetchUser(username: username) {
                        await MainActor.run {
                            firstName = member.firstName
                            lastName = member.lastName
                            dob = dateFormatter.date(from: member.dob)
                            pictureURL = member.pictureURL
                        }
                    }
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

}

#Preview {
    ProfileView(username: "USER")
}

