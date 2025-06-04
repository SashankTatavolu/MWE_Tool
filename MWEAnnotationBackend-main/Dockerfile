# Use an official Python runtime as a parent image
FROM python:3.8-slim

# Install PostgreSQL development files required for compiling psycopg2
RUN apt-get update && apt-get install -y libpq-dev gcc \
    # Clean up the apt cache to reduce image size
    && rm -rf /var/lib/apt/lists/*

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Install any needed packages specified in requirements.txt
# Make sure your requirements.txt includes psycopg2, not psycopg2-binary
RUN pip install --trusted-host pypi.python.org -r requirements.txt

# Make port 80 available to the world outside this container
EXPOSE 5000

# Define environment variable
ENV NAME World

# Run app.py when the container launches
CMD ["python", "run.py"]