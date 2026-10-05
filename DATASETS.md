# Dog motion data

Checked 2026-10-02. The raw files stay on the public repositories. This app keeps the links. Distance is still peaks times meters per peak. The Small 0.37 m and Large 0.83 m presets are published same-paw walk strides from Kim, Kazmierczak, and Breur, *American Journal of Veterinary Research* 2011.

The activity label uses the collar means in Karimjee, Harron, Piercy, and Daley, *Royal Society Open Science* (2024): lie 0.02 g, sit 0.08 g, stand 0.13 g, walk 0.26 g, trot 0.59 g. The walk onset is the midpoint of the stand and walk means, 0.195 g. A one-second mean above the trot mean is labeled Galloping, which is a DogMove class without its own published mean. Peaks add distance during walking, trotting, and galloping.

## Harness and collar IMU

Movement Sensor Dataset for Dog Behavior Classification.

- DOI: https://doi.org/10.17632/vxhx934tbn.4
- Licence: CC BY 4.0
- 45 middle-to-large dogs. ActiGraph GT9X Link. 100 Hz accelerometer and gyroscope. One sensor on the harness back. One sensor on the neck collar.
- Labels include galloping, lying on chest, sitting, sniffing, standing, trotting, and walking.
- `DogMoveData_csv_format.zip` is 421 MB. The CSV has 10,611,068 rows. Columns cover back and neck accelerometer and gyroscope axes, the task, and up to three behavior labels.
- Description: Vehkaoja et al., *Data in Brief* 40 (2022) 107822. https://doi.org/10.1016/j.dib.2022.107822
- Classification paper: Kumpulainen et al., *Applied Animal Behaviour Science* 241 (2021) 105393. https://doi.org/10.1016/j.applanim.2021.105393
- Notebooks: https://github.com/benjamingray123/IMU-behaviour-classification
- Kaggle mirror of an earlier deposit: https://www.kaggle.com/datasets/benjamingray44/inertial-data-for-dog-behaviour-classification

Use the harness-back columns when you retune the movement threshold. The files have behavior labels. They have no measured course length, so they do not set meters per peak. Cite both papers if you publish a number from this set.

## Back, chest, and neck IMU

Inertial sensor dataset for Dog Posture Recognition.

- DOI: https://doi.org/10.17632/mpph6bmn7g.1
- Licence: CC BY 4.0
- 42 assistance dogs. ActiGraph GT9X Link. 100 Hz. Sensors on the back, neck, and chest.
- Labels: standing, sitting, lying down, walking, body shake. A second label marks static or dynamic.
- `df_raw.csv` is 546 MB.
- Code: https://github.com/mmarcato/dog_posture
- Paper: Marcato et al., *PLOS ONE* (2023). https://doi.org/10.1371/journal.pone.0286311

Use the back sensor and the walking-versus-standing labels for the same threshold check.

## Collar activity levels

A standardised approach to quantifying activity in domestic dogs.

- Article: https://doi.org/10.1098/rsos.240119
- Data: https://doi.org/10.5061/dryad.m0cfxppbs
- Collar Axivity AX3 on beagles and pet dogs. The Dryad files are summary rows.
- Published mean dynamic vector magnitude: lie down 0.02 g, sit 0.08 g, stand 0.13 g, walk 0.26 g, trot 0.59 g.

The Dog Pace slider starts at 0.15 g. Stand sits near that value. Walk and trot sit above it. The sensor and the magnitude formula differ from this app.

## Step counts and GPS distance, on request

Ladha, Belshaw, O'Sullivan, and Asher. A step in the right direction: an open-design pedometer algorithm for dogs. *BMC Veterinary Research* 14 (2018) 107. https://doi.org/10.1186/s12917-018-1422-3

Collar accelerometer at 100 Hz and ±8 g. Thirteen filmed dogs produced 4,695 video steps. The published algorithm detected 91%. A second group of ten dogs produced GPS walks totaling 20,184 m, with a reported mean similarity of 79%. The paper describes the method. The recordings are shared on request.

## Limb-mounted gait

These studies mount sensors on legs. A WHOOP on a harness is a different signal.

- Jenkins et al., *PLOS ONE* (2018). https://doi.org/10.1371/journal.pone.0198893. One IMU on a forelimb. Three dogs. 1,259 video-checked steps. The public spreadsheet is step timing.
- Zhang et al., *Scientific Reports* (2022). https://doi.org/10.1038/s41598-022-08676-1. Four limb IMUs on four dogs. The authors share data on request.

## Other public sets

African wild dog collar acceleration is on Zenodo as record 16890491. It is 16 Hz behavior labels from free-ranging wild dogs. Human gait collections on https://wearable-landscape.info/topics/open-accelerometer-datasets are people. https://github.com/Riei-Joaquim/dog-step-counter is firmware for an ESP32 board and contains no dog traces.
