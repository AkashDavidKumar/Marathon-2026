from flask import Flask, jsonify
from datetime import datetime
from config import Config
from extensions import socketio, cors

def create_app(config_class=Config):
    app = Flask(__name__, static_folder='../frontend', static_url_path='')
    app.config.from_object(config_class)

    # Initialize extensions
    cors.init_app(app, resources={r"/api/*": {"origins": app.config.get('FRONTEND_URL', '*')}})
    socketio.init_app(app, cors_allowed_origins="*")

    # --- PERFORMANCE MIDDLEWARE ---
    import time
    from flask import request, g

    @app.before_request
    def before_request():
        g.start_time = time.time()

    @app.after_request
    def after_request(response):
        # Calculate duration
        if hasattr(g, 'start_time'):
            duration = (time.time() - g.start_time) * 1000 # ms
            # Log slow requests (>1s)
            if duration > 1000:
                print(f"⚠️ SLOW API: {request.method} {request.path} took {duration:.2f}ms")
            # Log all for debug (optional, can be noisy)
            # print(f"API: {request.method} {request.path} took {duration:.2f}ms")

        # Cache Control
        if request.path.startswith('/api/static'):
            response.headers['Cache-Control'] = 'public, max-age=3600'
        elif request.path.startswith('/api/'):
            # Dynamic API - mostly no-cache or short cache
            # For now, let's allow 5 min private cache for non-sensitive GETs if architecturally safe
            # But contests are real-time, so strict short cache is better.
            response.headers['Cache-Control'] = 'private, max-age=0, no-cache' # Safety first for contest
        else:
            # Static files handled by Flask (dev mode mostly, Prod uses Nginx)
            if request.path.endswith('.css') or request.path.endswith('.js') or request.path.endswith('.png'):
                response.headers['Cache-Control'] = 'public, max-age=3600'

        return response
    # ------------------------------

    # Register Blueprints
    from routes.auth import bp as auth_bp
    from routes.contest import bp as contest_bp
    from routes.admin import bp as admin_bp
    from routes.leaderboard import bp as leaderboard_bp
    from routes.proctoring import bp as proctoring_bp

    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(contest_bp, url_prefix='/api/contest')
    app.register_blueprint(admin_bp, url_prefix='/api/admin')
    app.register_blueprint(leaderboard_bp, url_prefix='/api/leaderboard')

    app.register_blueprint(proctoring_bp, url_prefix='/api/proctoring')
    
    from routes.leader import bp as leader_bp
    app.register_blueprint(leader_bp, url_prefix='/api/leader')
    
    from routes.rankings import bp as rankings_bp
    app.register_blueprint(rankings_bp, url_prefix='/api/rankings')

    from routes.participant import bp as participant_bp
    app.register_blueprint(participant_bp, url_prefix='/api/participant')

    # Health Check Endpoint for AWS Load Balancer
    @app.route('/api/health')
    def health_check():
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.utcnow().isoformat(),
            'version': '1.0.0'
        })

    # Serve Static Files
    @app.route('/')
    def serve_index():
        return app.send_static_file('index.html')

    @app.route('/participant.html')
    def serve_participant():
        return app.send_static_file('participant.html')

    @app.route('/admin.html')
    def serve_admin():
        return app.send_static_file('admin.html')

    @app.route('/leaderboard.html')
    def serve_leaderboard():
        return app.send_static_file('leaderboard.html')

    @app.route('/results.html')
    def serve_results():
        return app.send_static_file('results.html')

    @app.route('/leader_login.html')
    def serve_leader_login():
        return app.send_static_file('leader_login.html')

    @app.route('/leader_dashboard.html')
    def serve_leader_dashboard():
        return app.send_static_file('leader_dashboard.html')
        
    @app.route('/favicon.ico')
    def favicon():
        return '', 204

    @app.errorhandler(Exception)
    def handle_global_error(e):
        from flask import request
        from werkzeug.exceptions import HTTPException
        
        # Determine status code
        code = 500
        if isinstance(e, HTTPException):
            code = e.code

        # API Requests -> JSON
        if request.path.startswith('/api/'):
            # Only log stack trace for 500s
            if code >= 500:
                import traceback
                traceback.print_exc()
            return jsonify({'error': str(e), 'success': False}), code

        # Static/Page Requests -> HTML (default behavior)
        if isinstance(e, HTTPException):
            return e
            
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e), 'message': 'Internal Server Error'}), 500

    return app

# Create app instance for Gunicorn
app = create_app()

if __name__ == '__main__':
    socketio.run(app, debug=app.config['DEBUG'], host='0.0.0.0', port=5000, allow_unsafe_werkzeug=app.config['DEBUG'])
    # Database configuration updated to debug_marathon_v3 - Force Reload
