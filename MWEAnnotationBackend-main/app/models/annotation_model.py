from datetime import datetime

from .. import db


class Annotation(db.Model):
    __tablename__ = 'annotations'

    id = db.Column(db.Integer, primary_key=True)
    word_phrase = db.Column(db.String(120), nullable=False)
    annotation = db.Column(db.Text, nullable=False)
    annotated_by = db.Column(db.Text, nullable=False)
    annotated_on = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    sentence_id = db.Column(db.Integer, db.ForeignKey('sentences.id'), nullable=False)
    project_id = db.Column(db.Integer, db.ForeignKey('projects.id'), nullable=False)
