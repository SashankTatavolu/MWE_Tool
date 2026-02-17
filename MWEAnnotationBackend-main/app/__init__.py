from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_marshmallow import Marshmallow
from flask_bcrypt import Bcrypt
from flask_jwt_extended import JWTManager
from flask_cors import CORS
from flask_mail import Mail


db = SQLAlchemy()
ma = Marshmallow()
bcrypt = Bcrypt()
mail = Mail() 


def create_app():
    app = Flask(__name__)
    app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://postgres:root@10.129.6.206/mweannotationplatform'
    # app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://postgres:Sashank123@localhost/mwe'
    # app.config['SQLALCHEMY_DATABASE_URI']='postgresql://postgres:password123@10.2.8.12/MWE_tool'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['JWT_SECRET_KEY'] = 'your_jwt_secret_key'
    
    app.config['MAIL_SERVER'] = 'smtp.gmail.com'
    app.config['MAIL_PORT'] = 587
    app.config['MAIL_USE_TLS'] = True
    app.config['MAIL_USERNAME'] = "mwa.iiith@gmail.com"
    app.config['MAIL_PASSWORD'] = "jjmd umfd lpds yzvh"
    mail.init_app(app)

    bcrypt.init_app(app)
    db.init_app(app)
    ma.init_app(app)
    jwt = JWTManager(app)
    CORS(app)

    with app.app_context():
        from .controllers.user_controller import user_blueprint
        from .controllers.project_controller import project_blueprint
        from .controllers.sentence_controller import sentence_blueprint
        from .controllers.annotation_controller import annotation_blueprint
        app.register_blueprint(project_blueprint, url_prefix="/project")
        app.register_blueprint(user_blueprint, url_prefix="/user")
        app.register_blueprint(sentence_blueprint, url_prefix="/sentence")
        app.register_blueprint(annotation_blueprint, url_prefix="/annotation")

        db.create_all()

    return app
