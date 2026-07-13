FROM gingersociety/python3

RUN python -m pip install --upgrade pip
RUN pip install setuptools wheel twine sphinx furo sphinx-sitemap
