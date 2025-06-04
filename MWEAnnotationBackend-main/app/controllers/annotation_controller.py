from flask import Blueprint, request, jsonify, Response
from flask_jwt_extended import jwt_required, get_jwt_identity
from .. import db
from ..models.annotation_model import Annotation
from ..models.sentence_model import Sentence
from ..schemas.annotation_schema import annotations_schema
from ..services.annotation_service import  search_annotations, search_sentences_by_annotation, upload_annotated_xml, upload_annotations, get_annotations, get_project_annotations, \
    generate_annotations_xml, generate_annotations_txt

annotation_blueprint = Blueprint('annotation_blueprint', __name__)


@annotation_blueprint.route("/add_annotations", methods=['POST'])
@jwt_required()
def upload_annotation_route():
    current_user = get_jwt_identity()
    annotation_data = request.json
    return upload_annotations(annotation_data, current_user)


@annotation_blueprint.route("/get_annotations", methods=['POST'])
@jwt_required()
def get_annotations_route():
    current_user = get_jwt_identity()
    data = request.json
    annotation_data = get_annotations(data)
    return annotations_schema.jsonify(annotation_data)

@annotation_blueprint.route("/clear_annotations", methods=['POST'])
@jwt_required()
def clear_annotations_route():
    data = request.json
    sentence_id = data.get("sentence_id")
    project_id = data.get("project_id")
    
    if not sentence_id or not project_id:
        return jsonify({'message': 'sentence_id and project_id are required'}), 400

    Annotation.query.filter_by(sentence_id=sentence_id, project_id=project_id).delete()

    sentence = Sentence.query.get(sentence_id)
    if sentence:
        sentence.is_annotated = False
        db.session.add(sentence)

    db.session.commit()
    return jsonify({'message': 'Annotations cleared successfully'}), 200



@annotation_blueprint.route('/download_annotations_xml', methods=['POST'])
@jwt_required()
def download_annotations_xml():
    project_id = request.json['project_id']
    sentences = get_project_annotations(project_id)
    xml_content = generate_annotations_xml(sentences)

    response = Response(xml_content, mimetype='application/xml')
    response.headers['Content-Disposition'] = f'attachment; filename=project_{project_id}_annotations.xml'

    return response


@annotation_blueprint.route('/download_annotations_text', methods=['POST'])
@jwt_required()
def download_annotations_text():
    project_id = request.json['project_id']
    sentences = get_project_annotations(project_id)
    txt_content = generate_annotations_txt(sentences)

    # Create a response with the TXT content and appropriate headers
    # to trigger download on the client side
    response = Response(txt_content, mimetype='text/plain')
    response.headers['Content-Disposition'] = f'attachment; filename=project_{project_id}_annotations.txt'

    return response


@annotation_blueprint.route("/upload_annotated_xml", methods=['POST'])
@jwt_required()
def upload_annotated_xml_route():
    current_user = get_jwt_identity()

    # Ensure a file is provided
    if 'file' not in request.files:
        return jsonify({'message': 'No file part in the request'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'message': 'No file selected for uploading'}), 400

    return upload_annotated_xml(file, current_user)



@annotation_blueprint.route("/search_annotations", methods=['POST'])
@jwt_required()
def search_annotations_route():
    data = request.json

    # Validate input
    word_phrase = data.get("word_phrase")
    if not word_phrase:
        return jsonify({'message': 'word_phrase is required'}), 400

    # Call the service method
    results = search_annotations(word_phrase)

    if not results:
        return jsonify({'message': 'No annotations found matching the criteria'}), 404

    return jsonify(results), 200


@annotation_blueprint.route("/search_sentences_by_annotation", methods=['POST'])
@jwt_required()
def search_sentences_by_annotation_route():
    current_user = get_jwt_identity()
    data = request.json
    annotation_text = data.get('annotation_text')
    project_title = data.get('project_title')

    if not annotation_text:
        return jsonify({'message': 'Annotation text is required'}), 400

    # If project_title is "All" or empty, set it to None to fetch all projects
    if not project_title or project_title.lower() == "all":
        project_title = None

    results = search_sentences_by_annotation(annotation_text, project_title)
    return jsonify(results), 200
