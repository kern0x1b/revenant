import SwiftUI

struct Post: Identifiable {
    let id: Int
    let author: String
    let text: String
    var likes: Int
    var liked = false
    var comments: [String] = []
}

struct Avatar: View {
    let name: String
    var body: some View {
        Text(String(name.prefix(1)))
            .font(.headline)
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .background(Circle().fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)))
    }
}

struct PostRow: View {
    @Binding var post: Post
    @State private var showComments = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Avatar(name: post.author)
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author).font(.headline)
                    Text("2h ago").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Menu {
                    Button("Share") {}
                    Button("Report", role: .destructive) {}
                } label: { Image(systemName: "ellipsis").padding(8) }
            }
            Text(post.text).font(.body).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 24) {
                Button {
                    withAnimation(.spring()) {
                        post.liked.toggle()
                        post.likes += post.liked ? 1 : -1
                    }
                } label: {
                    Label("\(post.likes)", systemImage: post.liked ? "heart.fill" : "heart")
                        .foregroundColor(post.liked ? .red : .secondary)
                }
                Button { showComments = true } label: {
                    Label("\(post.comments.count)", systemImage: "bubble.right")
                }
                Spacer()
            }
            .buttonStyle(.plain)
            .font(.subheadline)
        }
        .padding(.vertical, 6)
        .sheet(isPresented: $showComments) {
            NavigationView {
                List(post.comments, id: \.self) { Text($0) }
                    .navigationTitle("Comments")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showComments = false } } }
            }
        }
    }
}

struct StoriesBar: View {
    let names = ["Ann", "Bob", "Cy", "Dee", "Eve", "Fay", "Gus"]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(names, id: \.self) { name in
                    VStack {
                        Avatar(name: name).overlay(Circle().stroke(Color.orange, lineWidth: 2).padding(-3))
                        Text(name).font(.caption)
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 74)
    }
}

struct FeedView: View {
    @State private var posts = (1...6).map { Post(id: $0, author: ["Ann", "Bob", "Cy"][$0 % 3], text: "Post number \($0): the quick brown fox jumps over the lazy dog, again and again until it wraps.", likes: $0 * 3, comments: ["Nice!", "Agreed"]) }
    @State private var composing = false
    @State private var draft = ""

    var body: some View {
        NavigationView {
            List {
                StoriesBar().listRowInsets(EdgeInsets())
                ForEach($posts) { $post in PostRow(post: $post) }
            }
            .listStyle(.plain)
            .navigationTitle("Feed")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { composing = true } label: { Image(systemName: "square.and.pencil") }
                }
            }
            .sheet(isPresented: $composing) {
                NavigationView {
                    TextEditor(text: $draft)
                        .padding()
                        .navigationTitle("New post")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { composing = false } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Post") {
                                    posts.insert(Post(id: posts.count + 1, author: "Me", text: draft, likes: 0), at: 0)
                                    draft = ""; composing = false
                                }.disabled(draft.isEmpty)
                            }
                        }
                }
            }
        }
    }
}
