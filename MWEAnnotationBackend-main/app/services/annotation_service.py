import datetime
from flask import jsonify
import xml.etree.ElementTree as ET
from sqlalchemy import or_
from app.models.project_model import Project
import xml.etree.ElementTree as ET
import html
import re
import datetime

from .. import db
from ..models.annotation_model import Annotation
from ..models.sentence_model import Sentence


def upload_annotations(annotations_data, user):
    if not annotations_data:
        return jsonify({'message': 'No input data provided'}), 400
    if not isinstance(annotations_data, list):
        return jsonify({'message': 'Input data should be a list of annotations'}), 400

    # First, identify all unique sentence and project ID combinations
    unique_sentence_project_ids = {(data['sentence_id'], data['project_id']) for data in annotations_data}

    # Delete existing annotations for these combinations
    for sentence_id, project_id in unique_sentence_project_ids:
        Annotation.query.filter_by(sentence_id=sentence_id, project_id=project_id).delete()

    updated_sentence_ids = set()  # To keep track of sentence IDs that are updated

    for annotation_data in annotations_data:
        annotation = Annotation(
            word_phrase=annotation_data['word_phrase'],
            annotation=annotation_data['annotation'],
            annotated_by=user,
            annotated_on=datetime.datetime.now(),
            sentence_id=annotation_data['sentence_id'],
            project_id=annotation_data['project_id']
        )
        db.session.add(annotation)

        # Check if this sentence ID has not been updated already in this session
        if annotation_data['sentence_id'] not in updated_sentence_ids:
            sentence = Sentence.query.get(annotation_data['sentence_id'])
            if sentence:
                sentence.is_annotated = True  # Set isAnnotated to True
                db.session.add(sentence)  # Mark the sentence object as modified
                updated_sentence_ids.add(annotation_data['sentence_id'])

    db.session.commit()

    return jsonify({'message': 'Annotation uploaded successfully'}), 201


def get_annotations(data):
    sentence_id = data['sentence_id']
    annotations = Annotation.query.filter_by(sentence_id=sentence_id).all()
    return annotations


def get_project_annotations(project_id):
    sentences = Sentence.query.filter_by(project_id=project_id).all()
    return sentences


def generate_annotations_xml(sentences):
    root = ET.Element("project")
    sentences_elem = ET.SubElement(root, "sentences")

    for sentence in sentences:
        sentence_attr = {
            "id": str(sentence.id),
            "text": sentence.content,
            "isAnnotated": str(sentence.is_annotated),
            "project_id": str(sentence.project_id)
        }
        sentence_elem = ET.SubElement(sentences_elem, "sentence", **sentence_attr)
        annotations_elem = ET.SubElement(sentence_elem, "annotations")

        for annotation in sentence.annotations:
            annotation_attr = {
                "id": str(annotation.id),
                "word_phrase": annotation.word_phrase,
                "annotation": annotation.annotation,
                "annotated_by": annotation.annotated_by,
                "annotated_on": annotation.annotated_on.strftime("%Y-%m-%d"),
            }
            ET.SubElement(annotations_elem, "annotation", **annotation_attr)

    return ET.tostring(root, encoding='unicode', method='xml')


def generate_annotations_txt(sentences):
    lines = []
    for sentence in sentences:
        lines.append(f"Sentence ID: {sentence.id}, Text: '{sentence.content}'")
        for annotation in sentence.annotations:
            lines.append(f"\tAnnotation: {annotation.annotation}, Word_Phrase: '{annotation.word_phrase}', Annotated by: {annotation.annotated_by}, Annotated on: {annotation.annotated_on.strftime('%Y-%m-%d')}")
        lines.append("")

    return "\n".join(lines)


def upload_annotated_xml(file, user):
    try:
        # Parse the XML file
        tree = ET.parse(file)
        root = tree.getroot()
    
        for sentence_elem in root.findall(".//sentence"):
            sentence_id = sentence_elem.get("id")
            raw_text = sentence_elem.get("text")
            is_annotated = sentence_elem.get("isAnnotated") == "True"
            project_id = sentence_elem.get("project_id")

            # Decode HTML entities in the raw sentence text
            decoded_text = html.unescape(raw_text)

            # Extract annotations (e.g., <ENAMEX>, <NUMEX>, etc.)
            annotations = []
            def annotation_extractor(match):
                annotation_type = match.group(1)  # e.g., ENAMEX
                attributes = match.group(2)      # e.g., ID="256" TYPE="FACILITIES"
                annotated_word = html.unescape(match.group(3))  # Annotated text

                # Parse annotation attributes (like ID, TYPE)
                annotation_attrs = dict(re.findall(r'(\w+)="(.*?)"', attributes))
                annotations.append({
                    'type': annotation_type,
                    'text': annotated_word,
                    'attributes': annotation_attrs
                })

                # Return just the annotated word for the cleaned sentence text
                return annotated_word

            # Regex to match annotation tags (e.g., <ENAMEX ID="256" TYPE="FACILITIES">मंत्रा राजभाषा</ENAMEX>)
            clean_text = re.sub(r'<(\w+)(.*?)>(.*?)</\1>', annotation_extractor, decoded_text)

            # Save the cleaned sentence in the database
            sentence = Sentence.query.get(sentence_id)
            if not sentence:
                sentence = Sentence(
                    id=sentence_id,
                    content=clean_text,  # Save cleaned sentence without tags
                    is_annotated=is_annotated,
                    project_id=project_id
                )
            else:
                sentence.content = clean_text
                sentence.is_annotated = is_annotated
            db.session.add(sentence)

            # Save annotations in the database
            if is_annotated:
                # Clear existing annotations for this sentence
                Annotation.query.filter_by(sentence_id=sentence_id, project_id=project_id).delete()

                for annotation in annotations:
                    annotation_id = annotation['attributes'].get('ID')
                    annotation_type = annotation['type']
                    annotation_subtype = annotation['attributes'].get('TYPE', '')
                    annotated_word = annotation['text']

                    annotation_record = Annotation(
                        id=annotation_id,
                        word_phrase=annotated_word,
                        annotation=f"{annotation_type} ({annotation_subtype})",
                        annotated_by=user,
                        annotated_on=datetime.datetime.now(),
                        sentence_id=sentence_id,
                        project_id=project_id
                    )
                    db.session.add(annotation_record)

        db.session.commit()
        return jsonify({'message': 'Annotated XML uploaded successfully'}), 201

    except ET.ParseError:
        return jsonify({'message': 'Invalid XML format'}), 400
    except Exception as e:
        return jsonify({'message': f'An error occurred: {str(e)}'}), 500


def search_annotations(word_phrase):
    # Start the query for annotations filtered by word_phrase
    query = Annotation.query.filter(Annotation.word_phrase.ilike(f"%{word_phrase}%"))

    # Join Sentence and Project to fetch related data
    query = query.join(Sentence).join(Project)

    # Fetch the annotations
    annotations = query.all()

    results = [
        {
            "id": annotation.id,
            "word_phrase": annotation.word_phrase,
            "annotation": annotation.annotation,
            "annotated_by": annotation.annotated_by,
            "annotated_on": annotation.annotated_on.strftime("%Y-%m-%d"),
            "sentence_text": annotation.sentence.content,  # Fetch sentence text
            "sentence_id": annotation.sentence_id,
            "project_id": annotation.project_id,
            "project_title": annotation.project.title
        }
        for annotation in annotations
    ]

    return results


def search_sentences_by_annotation(annotation_text, project_title=None):
    # Start the query for annotations that match the annotation text
    query = Annotation.query \
        .join(Sentence) \
        .join(Project) \
        .filter(Annotation.annotation.ilike(f"%{annotation_text}%"))

    # If project_title is provided and not set to "All", filter by project title
    if project_title and project_title.lower() != "All":
        query = query.filter(Project.title.ilike(f"%{project_title}%"))

    # Fetch matching annotations
    annotations = query.all()

    # Format results
    results = [
        {
            "word_phrase": annotation.word_phrase,
            "annotation": annotation.annotation,
            "sentence_text": annotation.sentence.content,
            "sentence_id": annotation.sentence_id,
            "project_id": annotation.project_id,
            "project_title": annotation.project.title,
        }
        for annotation in annotations
    ]

    return results
