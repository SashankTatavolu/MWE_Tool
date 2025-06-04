from datetime import datetime
from .. import db

class Project(db.Model):
    __tablename__ = 'projects'

    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(120), nullable=False)
    description = db.Column(db.Text, nullable=False)
    language = db.Column(db.String(50), nullable=False)
    file_text = db.Column(db.Text, nullable=False)
    uploaded_by = db.Column(db.Text, nullable=False)
    uploaded_on = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    assigned_to = db.Column(db.Integer, nullable=True)  # ✅ Change from String to Integer
    is_assigned = db.Column(db.Boolean, nullable=False, default=False)  # Boolean flag
    sentences = db.relationship('Sentence', backref='project', lazy=True)
    annotations = db.relationship('Annotation', backref='project', lazy=True)
