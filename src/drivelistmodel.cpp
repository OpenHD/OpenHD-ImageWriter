        /*
        * SPDX-License-Identifier: Apache-2.0
        * Copyright (C) 2020 Raspberry Pi Ltd
        */

        #include "drivelistmodel.h"
        #include "config.h"
        #include "dependencies/drivelist/src/drivelist.hpp"
        #include <QSet>
        #include <QDebug>
        #include <QTcpSocket>
        #include <QNetworkAccessManager>
        #include <QNetworkReply>
        #include <QEventLoop>
        #include <QDomDocument>
        #include <QTimer>
        #include <QProcess>
        #include <QRegularExpression>
        #include <QSysInfo>


        DriveListModel::DriveListModel(QObject *parent)
            : QAbstractListModel(parent)
        {
            _invalidXmlSources.clear();
            _rolenames = {
                {deviceRole, "device"},
                {descriptionRole, "description"},
                {sizeRole, "size"},
                {isNetRole, "isNet"},
                {isUsbRole, "isUsb"},
                {isScsiRole, "isScsi"},
                {isReadOnlyRole, "isReadOnly"},
                {mountpointsRole, "mountpoints"}
            };

            // Enumerate drives in seperate thread, but process results in UI thread
            connect(&_thread, SIGNAL(newDriveList(std::vector<Drivelist::DeviceDescriptor>)), SLOT(processDriveList(std::vector<Drivelist::DeviceDescriptor>)));
        }

        int DriveListModel::rowCount(const QModelIndex &) const
        {
            return _drivelist.count();
        }

        QHash<int, QByteArray> DriveListModel::roleNames() const
        {
            return _rolenames;
        }

        QVariant DriveListModel::data(const QModelIndex &index, int role) const
        {
            int row = index.row();
            if (row < 0 || row >= _drivelist.count())
                return QVariant();

            QByteArray propertyName = _rolenames.value(role);
            if (propertyName.isEmpty())
                return QVariant();
            else
                return _drivelist.values().at(row)->property(propertyName);
        }

        QStringList DriveListModel::scanLocalDevices()
        {
            QStringList ipList;
            QProcess proc;
        
        #ifdef Q_OS_WIN
            proc.start("arp", QStringList() << "-a");
        #elif defined(Q_OS_LINUX)
            proc.start("ip", QStringList() << "neigh");
        #else
            qDebug() << "Unsupported OS for ARP scan";
            return ipList;
        #endif
        
            if (!proc.waitForFinished(1000))
                return ipList;
        
            QString output = proc.readAllStandardOutput();
            output.replace("\r", "");  // Normalize line endings
        
            QRegularExpression ipRegex(R"(192\.168\.\d+\.\d+)");
            QRegularExpressionMatchIterator it = ipRegex.globalMatch(output);
        
            while (it.hasNext()) {
                QString ip = it.next().captured(0).trimmed();
                if (!ipList.contains(ip))
                    ipList << ip;
            }
        
            //qDebug() << "[Parsed IPs]" << ipList;
        
            return ipList;
        }
        


        void DriveListModel::processDriveList(std::vector<Drivelist::DeviceDescriptor> l)
        {
            bool changes = false;
            bool filterSystemDrives = DRIVELIST_FILTER_SYSTEM_DRIVES;
            QSet<QString> drivesInNewList;

            // === Cross-Platform XML Drive Discovery BEGIN ===
            QStringList ipList = scanLocalDevices();
            QNetworkAccessManager manager;

            for (const QString &ip : ipList) {
                if (_virtualDriveSources.contains(ip)) {
                    qDebug() << "Skipping known IP:" << ip;
                    continue;
                }
                if (_invalidXmlSources.contains(ip)) {
                    qDebug() << "Skipping known invalid IP:" << ip;
                    continue;
                }
                qDebug() << "Trying IP:" << ip;
                
                QUrl url("http://" + ip + "/index.xml");
                QNetworkRequest request(url);

                QNetworkReply *reply = manager.get(request);

                QEventLoop loop;
                QTimer timer;
                timer.setSingleShot(true);
                QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
                QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
                timer.start(200);
                loop.exec();

                if (!timer.isActive()) {
                    //qDebug() << "Timeout while connecting to" << ip;
                    reply->abort();
                }

                if (reply->error() == QNetworkReply::NoError) {
                    QDomDocument doc;
                    if (doc.setContent(reply->readAll())) {
                        QDomElement root = doc.documentElement(); // <drives>
                        QDomNodeList driveNodes = root.elementsByTagName("drive");
                        _virtualDriveSources.insert(ip);

                    for (int i = 0; i < driveNodes.count(); ++i) {
                        QDomElement el = driveNodes.at(i).toElement();

                        Drivelist::DeviceDescriptor d;
                        d.device = el.firstChildElement("device").text().toStdString();
                        d.description = el.firstChildElement("description").text().toStdString();
                        d.size = el.firstChildElement("size").text().toULongLong();
                        d.isNET = el.firstChildElement("isNET").text() == "true";
                        d.isUSB = el.firstChildElement("isUSB").text() == "true";
                        d.isSCSI = el.firstChildElement("isSCSI").text() == "true";
                        d.isReadOnly = el.firstChildElement("isReadOnly").text() == "true";
                        d.isSystem = false;

                        QStringList fakeMountpoints;
                        fakeMountpoints << ip;
                        d.mountpoints = { ip.toStdString() };

                        QString key = QString::fromStdString(d.device) + ":" + QString::number(d.size); // Unique key
                        _virtualDrives[key] = d; //store it persistently
                    }
                    }
                } else if (reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() == 404) {
                    qDebug() << "404 Not Found at" << ip << "- blacklisting";
                    _invalidXmlSources.insert(ip);
                } else {
                   //qDebug() << "No index.xml at" << ip << ":" << reply->errorString();
                }

                reply->deleteLater();
            }
            // === Cross-Platform XML Drive Discovery END ===

            for (const auto &d : _virtualDrives) {
                l.push_back(d);
            }
            for (auto &i: l)
            {
                // Convert STL vector<string> to Qt QStringList
                QStringList mountpoints;
                for (auto &s: i.mountpoints)
                {
                    mountpoints.append(QString::fromStdString(s));
                }

                if (filterSystemDrives)
                {
                    if (i.isSystem)
                        continue;
                }
                // Should already be caught by isSystem variable, but just in case...
                if (mountpoints.contains("/") || mountpoints.contains("C://"))
                    continue;

                // Skip zero-sized devices
                if (i.size == 0)
                    continue;

        #ifdef Q_OS_DARWIN
                if (i.isVirtual)
                    continue;
        #endif

                QString deviceNamePlusSize = QString::fromStdString(i.device)+":"+QString::number(i.size);
                if (i.isReadOnly)
                    deviceNamePlusSize += "ro";
                drivesInNewList.insert(deviceNamePlusSize);

                if (!_drivelist.contains(deviceNamePlusSize))
                {
                    // Found new drive
                    if (!changes)
                    {
                        beginResetModel();
                        changes = true;
                    }

                    _drivelist[deviceNamePlusSize] = new DriveListItem(QString::fromStdString(i.device), QString::fromStdString(i.description), i.size, i.isNET, i.isUSB, i.isSCSI, i.isReadOnly, mountpoints, this);
                }
            }

            // Look for drives removed
            QStringList drivesInOldList = _drivelist.keys();
            for (auto &device: drivesInOldList)
            {
                if (!drivesInNewList.contains(device))
                {
                    if (!changes)
                    {
                        beginResetModel();
                        changes = true;
                    }

                    _drivelist.value(device)->deleteLater();
                    _drivelist.remove(device);
                }
            }

            if (changes)
                endResetModel();
        }

        void DriveListModel::startPolling()
        {
            _thread.start();
        }

        void DriveListModel::stopPolling()
        {
            _thread.stop();
        }
