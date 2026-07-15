FROM docker.gingersociety.org/ginger-society/python3:latest

RUN python -m pip install --upgrade pip
RUN pip install setuptools wheel twine sphinx furo sphinx-sitemap
