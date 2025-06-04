from .. import db


class Sentence(db.Model):
    __tablename__ = 'sentences'

    id = db.Column(db.Integer, primary_key=True,autoincrement=True)
    content = db.Column(db.Text, nullable=False)
    sentence_number = db.Column(db.Integer, nullable=False)
    is_annotated = db.Column(db.Boolean, default=False, nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True) 
    project_id = db.Column(db.Integer, db.ForeignKey('projects.id'), nullable=False)
    annotations = db.relationship('Annotation', backref='sentence', lazy=True)

    __table_args__ = (db.UniqueConstraint('id', 'project_id', name='unique_sentence_per_project'),)