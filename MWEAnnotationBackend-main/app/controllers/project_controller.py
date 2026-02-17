from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy import func

from .. import db
from ..models.annotation_model import Annotation
from ..models.user_model import User
from ..models.project_model import Project

from ..services.project_service import (
    assign_user_to_project,
    create_project,
    delete_project,
    get_projects_with_annotation_counts_for_user,
    get_projects_with_annotation_counts,
    is_user_assigned_to_project,
    update_project_title,
    send_assignment_email
)

from ..services.user_service import (
    get_user_language,
    get_user_role,
    get_user_id,
    get_user_organisation
)

project_blueprint = Blueprint('project_blueprint', __name__)


# ============================================================
# GET PROJECT LIST (Now includes MWE count per project)
# ============================================================
@project_blueprint.route('/get_project_list', methods=['GET'])
@jwt_required()
def get_project_list():

    current_user = get_jwt_identity()
    user_role = get_user_role(current_user)
    user_language = get_user_language(current_user)
    user_id = get_user_id(current_user)
    user_organisation = get_user_organisation(current_user)

    # Get projects depending on role
    if user_role == 'Admin':
        projects_with_counts = get_projects_with_annotation_counts(
            user_language,
            user_organisation
        )
    else:
        projects_with_counts = get_projects_with_annotation_counts_for_user(
            user_id
        )

    projects_data = []

    for project, total_count, completed_count in projects_with_counts:

        # 🔥 MWE COUNT PER PROJECT
        mwe_count = (
            db.session.query(func.count(Annotation.id))
            .filter(Annotation.project_id == project.id)
            .scalar()
        )

        project_data = {
            "id": project.id,
            "title": project.title,
            "description": project.description,
            "language": project.language,
            "completed": completed_count,
            "total": total_count,
            "mwe_count": mwe_count or 0 
        }

        projects_data.append(project_data)

    return jsonify(projects_data), 200


@project_blueprint.route('/add_project', methods=['POST'])
@jwt_required()
def add_project():
    current_user = get_jwt_identity()
    
    # Get JSON data
    data = request.form.to_dict()  # Allows JSON and file uploads

    # Get the uploaded file (if any)
    file = request.files.get('file')

    if file:
        filename = file.filename.lower()
        if not (filename.endswith('.txt') or filename.endswith('.xml')):
            return jsonify({'message': 'Invalid file format. Please upload a .txt or .xml file.'}), 400
        
        # Extract the content from the file
        try:
            file_content = file.read().decode('utf-8')
            print("File Content Read:", file_content)  # Debugging

            # Add the file content to the data dictionary
            data['file_text'] = file_content
        except Exception as e:
            return jsonify({'message': f'Error reading file: {str(e)}'}), 500
    else:
        print("No file uploaded!")  # Debugging

    # Ensure 'file_text' is present before passing to create_project
    if 'file_text' not in data:
        return jsonify({'message': 'Missing file_text in request'}), 400
    
    print("Data before project creation:", data)  # Debugging

    # Process the file (text or XML)
    project = create_project(data, current_user)  

    # Handle error responses from create_project
    if isinstance(project, tuple):  # Means create_project returned (jsonify({...}), status_code)
        return project

    # Return success response
    return jsonify({
        "message": "Project created successfully!",
        "project_id": project.id,
        "title": project.title,
        "language": project.language
    }), 201



@project_blueprint.route('/delete_project/<int:project_id>', methods=['DELETE'])
@jwt_required()
def delete_project_route(project_id):
    current_user = get_jwt_identity()
    user_role = get_user_role(current_user)
    
    # Only allow admins to delete projects
    if user_role != 'Admin':
        return {"message": "Permission denied"}, 403

    # Call the delete_project function
    result, status_code = delete_project(project_id)
    return jsonify(result), status_code



@project_blueprint.route('/is_user_assigned/<int:project_id>', methods=['GET'])
@jwt_required()
def is_user_assigned_route(project_id):
    # Call the service function to check user assignment
    result, status_code = is_user_assigned_to_project(project_id)
    return jsonify(result), status_code


@project_blueprint.route('/update_project_title/<int:project_id>', methods=['PUT'])
@jwt_required()
def update_project_title_route(project_id):
    current_user = get_jwt_identity()

    data = request.json
    new_title = data.get("title")

    if not new_title:
        return {"error": "New title is required"}, 400

    # Call the service function to update the project title
    result, status_code = update_project_title(project_id, new_title)
    return jsonify(result), status_code

@project_blueprint.route('/assign_user_to_project/<int:project_id>', methods=['POST'])
@jwt_required()
def assign_user_to_project_route(project_id):
    current_user = get_jwt_identity()
    if get_user_role(current_user) != 'Admin':
        return {"message": "Permission denied"}, 403

    data = request.json
    user_id = data.get("user_id")
    force = data.get("force", False)

    result, status_code = assign_user_to_project(project_id, user_id, force)

    # Send email only on successful assignment
    if status_code == 200:
        user = User.query.get(user_id)
        project = Project.query.get(project_id)
        if user and project:
            send_assignment_email(user.email, user.name, project.title)

    return jsonify(result), status_code
