import eventlet
eventlet.monkey_patch()  # Socket.io uchun eng tepada bo'lishi shart

import os
from datetime import datetime
from flask import Flask, request, jsonify, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from flask_socketio import SocketIO, emit, join_room, leave_room
from flask_cors import CORS
from werkzeug.utils import secure_filename

# --- KONFIGURATSIYA ---
app = Flask(__name__)
app.config['SECRET_KEY'] = 'safechat_ultra_2026'
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', 'sqlite:///safechat_v3.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['UPLOAD_FOLDER'] = 'uploads'

# Papkalarni yaratish
os.makedirs(os.path.join(app.config['UPLOAD_FOLDER'], 'posts'), exist_ok=True)

db = SQLAlchemy(app)
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='eventlet')

# --- MODELLAR (DATABASE) ---

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    is_online = db.Column(db.Boolean, default=False)

class Message(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    sender = db.Column(db.String(80), nullable=False)
    receiver = db.Column(db.String(80), nullable=False)
    content = db.Column(db.Text, nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    is_read = db.Column(db.Boolean, default=False)

class Post(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200))
    media_url = db.Column(db.String(500))
    post_type = db.Column(db.String(50)) # 'video' yoki 'image'
    views = db.Column(db.Integer, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# --- SOCKET.IO VOQEALARI (REAL-TIME) ---

@socketio.on('join')
def handle_join(data):
    username = data.get('username')
    if username:
        join_room(username)
        user = User.query.filter_by(username=username).first()
        if user:
            user.is_online = True
            db.session.commit()
        emit('user_status', {'username': username, 'status': 'online'}, broadcast=True)
        print(f"DEBUG: {username} kirdi")

@socketio.on('send_message')
def handle_send(data):
    sender = data.get('sender')
    receiver = data.get('receiver')
    content = data.get('content')
    chat_type = data.get('chat_type', 'private')

    # Bazaga saqlash
    new_msg = Message(sender=sender, receiver=receiver, content=content)
    db.session.add(new_msg)
    db.session.commit()

    message_data = {
        'id': new_msg.id,
        'sender': sender,
        'receiver': receiver,
        'content': content,
        'timestamp': datetime.utcnow().strftime('%H:%M'),
        'type': 'text'
    }

    if chat_type == 'group':
        emit('receive_message', message_data, room=receiver)
    else:
        # Shaxsiy xabarni qabul qiluvchining shaxsiy xonasiga yuboramiz
        emit('receive_message', message_data, room=receiver)
        # Yuboruvchining o'ziga ham nusxa (boshqa qurilmalari uchun)
        emit('receive_message', message_data, room=sender)

@socketio.on('disconnect')
def handle_disconnect():
    # Bu yerda foydalanuvchini offline qilish logikasini qo'shish mumkin
    pass

# --- API ROUTES (POSTS & REELS) ---

@app.route('/api/posts', methods=['GET'])
def get_posts():
    posts = Post.query.order_by(Post.created_at.desc()).all()
    return jsonify([{
        "id": p.id,
        "title": p.title,
        "media": p.media_url,
        "type": p.post_type,
        "views": p.views
    } for p in posts])

@app.route('/api/upload-reel', methods=['POST'])
def upload_reel():
    if 'video' not in request.files:
        return jsonify({"status": "error"}), 400
    
    file = request.files['video']
    title = request.form.get('title', 'Yangi Reel')
    
    filename = secure_filename(f"{datetime.now().timestamp()}_{file.filename}")
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], 'posts', filename)
    file.save(filepath)

    new_post = Post(title=title, media_url=f"/uploads/posts/{filename}", post_type='video')
    db.session.add(new_post)
    db.session.commit()

    return jsonify({"status": "success", "url": new_post.media_url})

# Statik fayllar uchun (Rasmlar va Videolar)
@app.route('/uploads/<path:filename>')
def serve_uploads(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

if __name__ == '__main__':
    with app.app_context():
        db.create_all() # Bazani yaratish
    socketio.run(app, host='0.0.0.0', port=5000, debug=True)