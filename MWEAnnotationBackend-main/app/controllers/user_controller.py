from datetime import timedelta
from ..models.user_model import User
from flask import Blueprint, request, jsonify
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from ..services.user_service import create_user, check_user, get_users_by_organisation, reset_password,  send_reset_otp, update_user_profile, verify_otp, get_user_details, send_feedback_email
from ..schemas.user_schema import user_schema
from ..models.sentence_model import Sentence
from .. import db

user_blueprint = Blueprint('user_blueprint', __name__)

@user_blueprint.route('/register', methods=['POST'])
def register_user():
    data = request.get_json()
    user = create_user(data)

    # Convert comma-separated string back to a list
    user_dict = {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "role": user.role,
        "organisation": user.organisation,
        "language": user.language.split(",")  # Convert back to a list
    }

    return jsonify(user_dict)



@user_blueprint.route('/login', methods=['POST'])
def login_user():
    data = request.get_json()
    user = check_user(data['email'], data['password'])
    if user:
        expires = timedelta(minutes=30)
        access_token = create_access_token(identity=data['email'], expires_delta=expires)
        return jsonify(
            access_token=access_token,
            user_id=user.id,  # Include user ID
            role=user.role,
            email=user.email,
            name=user.name,
            organisation=user.organisation  # Assuming a relationship to Organization
        ), 200
    else:
        return jsonify({"message": "Invalid email or password"}), 401


@user_blueprint.route('/protected', methods=['GET'])
@jwt_required()
def protected():
    current_user = get_jwt_identity()
    return jsonify(logged_in_as=current_user), 200

@user_blueprint.route('/organisation/<string:organisation>', methods=['GET'])
@jwt_required()  
def get_users_by_org(organisation):
    # Fetch users by organization
    users = get_users_by_organisation(organisation)

    if not users:
        return jsonify({"message": "No users found for this organisation"}), 404

    filtered_users = []

    for user in users:
        # Check if the user is assigned any sentences
        assigned_sentences = Sentence.query.filter_by(user_id=user.id).all()

        if not assigned_sentences:
            # User is not assigned to any sentence, add to list
            filtered_users.append({
                "id": user.id,
                "name": user.name,
                "languages": user.language  # Include language field
            })
        else:
            # Check if all assigned sentences are completed (is_annotated = True)
            all_completed = all(sentence.is_annotated for sentence in assigned_sentences)

            if all_completed:
                filtered_users.append({
                    "id": user.id,
                    "name": user.name,
                    "languages": user.language  # Include language field
                })

    if not filtered_users:
        return jsonify({"message": "No available users"}), 404

    return jsonify(filtered_users)  # No tuple, just jsonify response


@user_blueprint.route('/send-reset-otp', methods=['POST'])
def send_otp():
    data = request.get_json()
    email = data.get('email')

    if send_reset_otp(email):
        return jsonify({"message": "OTP sent to email"}), 200
    return jsonify({"error": "User not found"}), 404

@user_blueprint.route('/verify-reset-otp', methods=['POST'])
def verify_reset_otp():
    data = request.get_json()
    email = data.get('email')
    otp = data.get('otp')

    if verify_otp(email, otp):
        return jsonify({"message": "OTP verified successfully"}), 200
    return jsonify({"error": "Invalid OTP"}), 400

@user_blueprint.route('/reset-password', methods=['POST'])
def reset_user_password():
    data = request.get_json()
    email = data.get('email')
    new_password = data.get('new_password')

    if reset_password(email, new_password):
        return jsonify({"message": "Password reset successful"}), 200
    return jsonify({"error": "User not found"}), 404

@user_blueprint.route('/update-profile', methods=['PUT'])
@jwt_required()
def update_profile():
    current_email = get_jwt_identity()  # Get the logged-in user’s email
    data = request.get_json()

    updated_user = update_user_profile(current_email, data)
    if updated_user:
        return jsonify({"message": "Profile updated successfully"}), 200
    return jsonify({"error": "User not found"}), 404


@user_blueprint.route('/user-details', methods=['GET'])
@jwt_required()
def get_logged_in_user_details():
    current_email = get_jwt_identity()  # Get email from JWT token
    user_details = get_user_details(current_email)
    
    if user_details:
        return jsonify(user_details), 200
    return jsonify({"error": "User not found"}), 404


@user_blueprint.route('/delete-user/<int:user_id>', methods=['DELETE'])
@jwt_required()
def delete_user(user_id):
    current_email = get_jwt_identity()
    admin_user = User.query.filter_by(email=current_email).first()

    if not admin_user or admin_user.role != "Admin":
        return jsonify({"error": "Unauthorized access"}), 403

    user_to_delete = User.query.get(user_id)

    if not user_to_delete:
        return jsonify({"error": "User not found"}), 404

    # Ensure admin can only delete users from the same organisation
    if admin_user.organisation != user_to_delete.organisation:
        return jsonify({"error": "You can only delete users from your own organisation"}), 403

    # Prevent deleting other admins
    if user_to_delete.role == "Admin":
        return jsonify({"error": "Cannot delete another admin"}), 403

    db.session.delete(user_to_delete)
    db.session.commit()

    return jsonify({"message": f"User {user_to_delete.name} deleted successfully"}), 200


@user_blueprint.route('/submit-feedback', methods=['POST'])
@jwt_required()  # Protect this endpoint, requiring the user to be logged in
def submit_feedback():
    user_email = get_jwt_identity()  # Get the current user's email from the JWT token
    data = request.get_json()

    user_name = data.get('user_name')  # Name of the user submitting the feedback
    feedback_text = data.get('feedback_text')  # The feedback text

    # Call the function to send the feedback email to the admin
    if send_feedback_email(user_name, user_email, feedback_text):
        return jsonify({"message": "Feedback submitted successfully."}), 200
    else:
        return jsonify({"error": "Failed to send feedback email."}), 500