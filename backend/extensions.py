from flask_socketio import SocketIO
from flask_cors import CORS

# Configure Socket.IO for production with ALB
socketio = SocketIO(
    cors_allowed_origins="*",
    async_mode='threading',
    ping_timeout=60,
    ping_interval=25,
    logger=False,
    engineio_logger=False
)
cors = CORS()
