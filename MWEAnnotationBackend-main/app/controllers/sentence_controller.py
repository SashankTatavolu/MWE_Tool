from flask_mail import Message
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from flask_mail import Mail
from ..models.user_model import User
from ..schemas.sentence_schema import sentences_schema
from ..models.sentence_model import Sentence
from .. import db
from ..models.project_model import Project
from ..services.sentence_service import get_sentences, send_assignment_email

sentence_blueprint = Blueprint('sentence_blueprint', __name__)
mail = Mail()

@sentence_blueprint.route('/get_sentences', methods=['POST'])
@jwt_required()
def get_sentence():
    current_user = get_jwt_identity()
    data = request.json
    sentences = get_sentences(data)
    return sentences_schema.jsonify(sentences), 200

@sentence_blueprint.route('/get_sentence_ids', methods=['POST'])
@jwt_required()
def get_sentence_ids():
    """
    Fetches only the sentence IDs of a project.
    """
    data = request.json
    project_id = data.get("project_id")

    if not project_id:
        return jsonify({"message": "Project ID is required"}), 400

    sentences = Sentence.query.with_entities(Sentence.id).filter_by(project_id=project_id).all()

    if not sentences:
        return jsonify({"message": "No sentences found for this project"}), 404

    sentence_ids = [sentence.id for sentence in sentences]

    return jsonify({"sentence_ids": sentence_ids}), 200

@sentence_blueprint.route('/get_sentences_by_user', methods=['POST'])
@jwt_required()
def get_sentences_by_user():
    """
    Fetches all sentences assigned to a specific user for a specific project.
    """
    data = request.get_json()
    user_id = data.get("user_id")
    project_id = data.get("project_id")

    if not user_id or not project_id:
        return jsonify({"message": "User ID and Project ID are required"}), 400

    # Fetch sentences assigned to the given user and project
    assigned_sentences = Sentence.query.filter_by(user_id=user_id, project_id=project_id).all()

    if not assigned_sentences:
        return jsonify({"message": "No sentences assigned to this user for the given project"}), 404

    # Prepare response
    sentence_data = [
        {"id": sentence.id, "sentence_number": sentence.sentence_number, "content": sentence.content}
        for sentence in assigned_sentences
    ]

    return jsonify({"sentences": sentence_data}), 200



@sentence_blueprint.route('/get_sentence_status', methods=['POST'])
@jwt_required()
def get_sentence_status():
    """
    Fetches assigned and unassigned sentences for a project.
    """
    data = request.get_json()
    project_id = data.get("project_id")

    if not project_id:
        return jsonify({"message": "Project ID is required"}), 400

    assigned_sentences = Sentence.query.filter(Sentence.project_id == project_id, Sentence.user_id.isnot(None)).all()
    unassigned_sentences = Sentence.query.filter(Sentence.project_id == project_id, Sentence.user_id.is_(None)).all()

    return jsonify({
        "assigned_sentences": [sentence.id for sentence in assigned_sentences],
        "unassigned_sentences": [sentence.id for sentence in unassigned_sentences]
    }), 200


@sentence_blueprint.route('/check_assigned_sentences', methods=['GET'])
@jwt_required()
def get_assigned_sentences():
    """
    Fetches the sentence IDs assigned to the current user.
    """
    current_user_email = get_jwt_identity()
    user = User.query.filter_by(email=current_user_email).first()

    if not user:
        return jsonify({"message": "User not found"}), 404

    # Fetching sentences assigned to the user
    assigned_sentences = Sentence.query.filter(Sentence.user_id == user.id).all()


    if not assigned_sentences:
        return jsonify({"message": "No sentences assigned to the user"}), 200

    sentence_ids = [sentence.id for sentence in assigned_sentences]

    return jsonify({"assigned_sentence_ids": sentence_ids}), 200


@sentence_blueprint.route('/assign_sentences', methods=['POST'])
@jwt_required()
def assign_sentences():
    data = request.get_json()
    project_id = data.get("project_id")
    assignment_dict = data.get("assignments")  # List of {user_id: [sentence_id1, sentence_id2, ...]}

    if not project_id or not assignment_dict:
        return jsonify({"message": "Project ID and assignments are required"}), 400

    project = Project.query.get(project_id)
    if not project:
        return jsonify({"message": "Project not found"}), 404

    project_name = project.title  # Fetch project name

    # Fetch all sentences in the project that are unassigned
    available_sentences = {s.id: s for s in Sentence.query.filter_by(project_id=project_id, user_id=None).all()}

    email_notifications = []
    invalid_ids = set()

    for assign in assignment_dict:
        user_id = assign.get("user_id")
        sentence_ids = assign.get("sentence_ids", [])

        if not user_id or not sentence_ids:
            continue  # Skip if user_id is missing or no sentences provided

        user = User.query.get(user_id)
        if not user:
            continue  # Skip if user doesn't exist

        valid_sentence_ids = [sid for sid in sentence_ids if sid in available_sentences]
        invalid_ids.update(set(sentence_ids) - set(valid_sentence_ids))

        if valid_sentence_ids:
            for sentence_id in valid_sentence_ids:
                available_sentences[sentence_id].user_id = user_id  # Assign sentence to user

            email_notifications.append({
                "email": user.email,
                "name": user.name,
                "project_name": project_name,
                "sentence_ids": valid_sentence_ids  # Send exact assigned IDs
            })

    db.session.commit()

    # Send email notifications
    for notification in email_notifications:
        send_assignment_email(notification)

    message = "Sentences assigned successfully."
    if invalid_ids:
        message += f" However, the following sentence IDs were invalid or already assigned: {list(invalid_ids)}"

    return jsonify({"message": message}), 200

        